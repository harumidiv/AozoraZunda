import SwiftUI

/// 青空文庫の作品をさがす画面。図書館の中を歩いて本棚や司書さんを調べる
struct CatalogView: View {
    @Environment(CatalogStore.self) private var catalog
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LibraryGameView { interactable in
                switch interactable {
                case .shelf(let label):
                    path.append(ShelfRoute(label: label))
                case .librarian:
                    path.append(SearchRoute())
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationTitle("としょかん")
            .navigationDestination(for: ShelfRoute.self) { route in
                ShelfView(label: route.label)
            }
            .navigationDestination(for: SearchRoute.self) { _ in
                CatalogSearchView()
            }
            .navigationDestination(for: CatalogAuthor.self) { author in
                AuthorWorksView(author: author)
            }
            .navigationDestination(for: CatalogBook.self) { book in
                BookDetailView(book: book)
            }
            .navigationDestination(for: ReaderRoute.self) { route in
                ReaderView(book: route.book)
            }
        }
        .task {
            await catalog.loadIfNeeded()
        }
    }
}

private struct ShelfRoute: Hashable {
    let label: String
}

private struct SearchRoute: Hashable {}

/// 作品一覧の取得が終わるまでは読み込み中・エラーを表示する
private struct CatalogContent<Content: View>: View {
    @Environment(CatalogStore.self) private var catalog
    @ViewBuilder let content: () -> Content

    var body: some View {
        if catalog.books.isEmpty {
            switch catalog.phase {
            case .failed(let message):
                ContentUnavailableView {
                    Label("作品一覧を取得できませんでした", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("再試行") {
                        Task { await catalog.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            default:
                ProgressView("作品一覧を取得しています…")
            }
        } else {
            content()
        }
    }
}

/// かな行ごとの本棚。並んでいる作家を頭文字ごとに分けて表示する
private struct ShelfView: View {
    @Environment(CatalogStore.self) private var catalog
    let label: String

    var body: some View {
        CatalogContent {
            let authors = catalog.authorSections.first { $0.title == label }?.authors ?? []
            let groups = Dictionary(grouping: authors) { String($0.sortKey.prefix(1)) }
                .sorted { $0.key < $1.key }
            if authors.isEmpty {
                ContentUnavailableView("この棚には本がありません", systemImage: "books.vertical")
            } else {
                List {
                    ForEach(groups, id: \.key) { initial, members in
                        Section(initial) {
                            ForEach(members) { author in
                                NavigationLink(value: author) {
                                    AuthorRow(author: author)
                                }
                            }
                        }
                        .sectionIndexLabel(initial)
                    }
                }
                .listStyle(.plain)
                .listSectionIndexVisibility(.visible)
            }
        }
        .navigationTitle(label == "他" ? "「他」の棚" : "「\(label)」の棚")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AuthorRow: View {
    let author: CatalogAuthor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(author.name)
                Text(author.yomi)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(author.workCount)作品")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 司書さんに頼む検索
private struct CatalogSearchView: View {
    @Environment(CatalogStore.self) private var catalog
    @State private var query = ""

    var body: some View {
        CatalogContent {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "どんな本をおさがしですか？",
                    systemImage: "magnifyingglass",
                    description: Text("作品名・作家名・よみがなで検索できます")
                )
            } else {
                SearchResultsView(query: query)
            }
        }
        .navigationTitle("司書さんにたずねる")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "作品名・作家名・よみがな")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("作品一覧を更新", systemImage: "arrow.clockwise") {
                        Task { await catalog.refresh() }
                    }
                    .disabled(catalog.phase == .loading)
                    if let updatedAt = catalog.updatedAt {
                        Text("最終更新: \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                } label: {
                    Label("メニュー", systemImage: "ellipsis")
                }
            }
        }
    }
}

private struct SearchResultsView: View {
    @Environment(CatalogStore.self) private var catalog
    let query: String

    var body: some View {
        let results = catalog.search(query)
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                Section("\(results.count)件") {
                    ForEach(results) { book in
                        NavigationLink(value: book) {
                            BookRow(book: book)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct AuthorWorksView: View {
    @Environment(CatalogStore.self) private var catalog
    let author: CatalogAuthor

    var body: some View {
        List(catalog.works(byAuthor: author.id)) { book in
            NavigationLink(value: book) {
                BookRow(book: book, showsAuthor: false)
            }
        }
        .listStyle(.plain)
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BookRow: View {
    @Environment(LibraryStore.self) private var library
    let book: CatalogBook
    var showsAuthor = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.displayTitle)
                if showsAuthor {
                    Text(book.displayCredit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !book.translatorName.isEmpty {
                    Text("\(book.translatorName) 訳")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if library.isDownloaded(book.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("ダウンロード済み")
            }
        }
    }
}
