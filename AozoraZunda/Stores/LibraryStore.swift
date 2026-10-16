import Foundation
import Observation

/// ダウンロード済み作品（本棚）の管理
@Observable
final class LibraryStore {
    private(set) var books: [LibraryBook] = []
    private(set) var downloadingIDs: Set<String> = []

    private let directory: URL
    private var indexURL: URL { directory.appending(path: "library.json") }
    private var textsDirectory: URL { directory.appending(path: "texts", directoryHint: .isDirectory) }

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Library", directoryHint: .isDirectory)) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: textsDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let books = try? JSONDecoder().decode([LibraryBook].self, from: data) {
            self.books = books
        }
    }

    /// 最近読んだ順・ダウンロードが新しい順
    var sortedBooks: [LibraryBook] {
        books.sorted { ($0.lastOpenedAt ?? $0.downloadedAt) > ($1.lastOpenedAt ?? $1.downloadedAt) }
    }

    func isDownloaded(_ id: CatalogBook.ID) -> Bool {
        books.contains { $0.id == id }
    }

    func isDownloading(_ id: CatalogBook.ID) -> Bool {
        downloadingIDs.contains(id)
    }

    func libraryBook(for id: CatalogBook.ID) -> LibraryBook? {
        books.first { $0.id == id }
    }

    func download(_ book: CatalogBook) async throws {
        guard !isDownloaded(book.id), !isDownloading(book.id) else { return }
        downloadingIDs.insert(book.id)
        defer { downloadingIDs.remove(book.id) }

        let (data, response) = try await URLSession.shared.data(from: book.textURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LibraryError.httpStatus(http.statusCode)
        }
        try await Self.saveText(fromZip: data, to: textURL(for: book.id))

        books.append(LibraryBook(book: book, downloadedAt: .now))
        saveIndex()
    }

    func delete(_ id: CatalogBook.ID) {
        try? FileManager.default.removeItem(at: textURL(for: id))
        books.removeAll { $0.id == id }
        saveIndex()
    }

    func loadText(for id: CatalogBook.ID) async throws -> String {
        try await Self.readText(at: textURL(for: id))
    }

    func markOpened(_ id: CatalogBook.ID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].lastOpenedAt = .now
        saveIndex()
    }

    func updateProgress(_ id: CatalogBook.ID, progress: Double) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].progress = progress
        saveIndex()
    }

    private func textURL(for id: CatalogBook.ID) -> URL {
        textsDirectory.appending(path: "\(id).txt")
    }

    private func saveIndex() {
        do {
            let data = try JSONEncoder().encode(books)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("本棚の保存に失敗しました: \(error)")
        }
    }

    /// ZIP からテキストを取り出し、Shift_JIS から UTF-8 に変換して保存する
    @concurrent
    private static func saveText(fromZip data: Data, to url: URL) async throws {
        let textData = try ZipArchive(data: data).extractFirst(withExtension: "txt")
        guard let text = decodeJapaneseText(textData) else { throw LibraryError.unsupportedEncoding }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    @concurrent
    private static func readText(at url: URL) async throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    nonisolated private static func decodeJapaneseText(_ data: Data) -> String? {
        // 青空文庫のテキストは Shift_JIS。機種依存文字も読めるよう CP932 を優先する
        let cp932 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        ))
        for encoding in [cp932, .shiftJIS, .utf8] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return nil
    }
}

enum LibraryError: LocalizedError {
    case httpStatus(Int)
    case unsupportedEncoding

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status): "ダウンロードに失敗しました（HTTP \(status)）"
        case .unsupportedEncoding: "テキストの文字コードを判別できませんでした"
        }
    }
}
