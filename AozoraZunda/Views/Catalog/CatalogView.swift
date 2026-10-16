import SwiftUI

/// 青空文庫の作品をさがす画面（作家一覧と検索）
struct CatalogView: View {
    @Environment(CatalogStore.self) private var catalog
    @State private var query = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("さがす")
                .searchable(text: $query, prompt: "作品名・作家名・よみがな")
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

    @ViewBuilder
    private var content: some View {
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
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            AuthorListView(sections: catalog.authorSections)
        } else {
            SearchResultsView(query: query)
        }
    }
}

private struct AuthorListView: View {
    let sections: [AuthorSection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.authors) { author in
                        NavigationLink(value: author) {
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
                }
                .sectionIndexLabel(section.title)
            }
        }
        .listStyle(.plain)
        .listSectionIndexVisibility(.visible)
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
