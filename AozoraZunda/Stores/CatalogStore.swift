import Foundation
import Observation

/// 青空文庫の作品一覧の取得・キャッシュ・検索
@Observable
final class CatalogStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var books: [CatalogBook] = []
    private(set) var authorSections: [AuthorSection] = []
    private(set) var updatedAt: Date?
    private var index = CatalogIndex.empty

    private let cacheURL: URL

    init(cacheURL: URL = URL.applicationSupportDirectory.appending(path: "catalog.json")) {
        self.cacheURL = cacheURL
    }

    /// キャッシュがあればそれを読み、なければネットワークから取得する
    func loadIfNeeded() async {
        guard phase == .idle else { return }
        phase = .loading
        if let cached = try? await Self.readCache(at: cacheURL) {
            await apply(cached.books)
            updatedAt = cached.updatedAt
            phase = .loaded
        } else {
            await fetch()
        }
    }

    func refresh() async {
        guard phase != .loading else { return }
        phase = .loading
        await fetch()
    }

    func works(byAuthor authorID: String) -> [CatalogBook] {
        index.worksByAuthor[authorID] ?? []
    }

    func search(_ query: String) -> [CatalogBook] {
        let keywords = CatalogIndex.normalize(query)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !keywords.isEmpty else { return [] }
        return zip(index.sortedBooks, index.searchKeys)
            .filter { _, key in keywords.allSatisfy { key.contains($0) } }
            .map(\.0)
    }

    private func fetch() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: AozoraCatalogParser.catalogURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LibraryError.httpStatus(http.statusCode)
            }
            let fetchedBooks = try await Self.parseAndCache(zipData: data, to: cacheURL)
            await apply(fetchedBooks)
            updatedAt = .now
            phase = .loaded
        } catch {
            // 取得に失敗しても既存の一覧があればそれを使い続ける
            phase = books.isEmpty ? .failed(error.localizedDescription) : .loaded
        }
    }

    private func apply(_ books: [CatalogBook]) async {
        let index = await CatalogIndex.build(from: books)
        self.books = books
        self.index = index
        authorSections = index.authorSections
    }

    @concurrent
    private static func readCache(at url: URL) async throws -> CatalogCache {
        try JSONDecoder().decode(CatalogCache.self, from: Data(contentsOf: url))
    }

    @concurrent
    private static func parseAndCache(zipData: Data, to url: URL) async throws -> [CatalogBook] {
        let books = try AozoraCatalogParser.parseZip(zipData)
        let data = try JSONEncoder().encode(CatalogCache(updatedAt: .now, books: books))
        try data.write(to: url, options: .atomic)
        return books
    }
}

nonisolated struct AuthorSection: Identifiable, Sendable {
    let title: String
    let authors: [CatalogAuthor]
    var id: String { title }
}

nonisolated private struct CatalogCache: Codable {
    let updatedAt: Date
    let books: [CatalogBook]
}

/// 一覧表示・検索用に前計算したデータ
nonisolated private struct CatalogIndex: Sendable {
    let sortedBooks: [CatalogBook]
    let searchKeys: [String]
    let worksByAuthor: [String: [CatalogBook]]
    let authorSections: [AuthorSection]

    static let empty = CatalogIndex(sortedBooks: [], searchKeys: [], worksByAuthor: [:], authorSections: [])

    @concurrent
    static func build(from books: [CatalogBook]) async -> CatalogIndex {
        let sortedBooks = books.sorted { $0.titleSortKey < $1.titleSortKey }
        let searchKeys = sortedBooks.map { book in
            normalize([book.title, book.titleYomi, book.subtitle, book.authorName, book.authorYomi, book.translatorName].joined(separator: " "))
        }
        let worksByAuthor = Dictionary(grouping: sortedBooks, by: \.authorID)

        let authors = worksByAuthor.values.compactMap { works -> CatalogAuthor? in
            guard let first = works.first else { return nil }
            return CatalogAuthor(
                id: first.authorID,
                name: first.authorName,
                yomi: first.authorYomi,
                sortKey: first.authorSortKey,
                workCount: works.count
            )
        }
        .sorted { $0.sortKey < $1.sortKey }

        var sections: [AuthorSection] = []
        for (title, members) in Dictionary(grouping: authors, by: { kanaRow(of: $0.sortKey) }) {
            sections.append(AuthorSection(title: title, authors: members.sorted { $0.sortKey < $1.sortKey }))
        }
        sections.sort { rowOrder.firstIndex(of: $0.title) ?? .max < rowOrder.firstIndex(of: $1.title) ?? .max }

        return CatalogIndex(sortedBooks: sortedBooks, searchKeys: searchKeys, worksByAuthor: worksByAuthor, authorSections: sections)
    }

    /// 大文字小文字・ひらがなカタカナの違いを無視して検索するための正規化
    static func normalize(_ text: String) -> String {
        let hiragana = text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
        return hiragana.lowercased()
    }

    private static let rowOrder = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "他"]

    private static func kanaRow(of sortKey: String) -> String {
        guard let scalar = sortKey.unicodeScalars.first else { return "他" }
        switch scalar.value {
        case 0x3041...0x304A: return "あ"
        case 0x304B...0x3054: return "か"
        case 0x3055...0x305E: return "さ"
        case 0x305F...0x3069: return "た"
        case 0x306A...0x306E: return "な"
        case 0x306F...0x307D: return "は"
        case 0x307E...0x3082: return "ま"
        case 0x3083...0x3088: return "や"
        case 0x3089...0x308D: return "ら"
        case 0x308E...0x3094: return "わ"
        default: return "他"
        }
    }
}
