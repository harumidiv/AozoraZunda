import SwiftUI

/// ダウンロード済みの作品一覧
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    ContentUnavailableView(
                        "本棚は空です",
                        systemImage: "books.vertical",
                        description: Text("「さがす」から読みたい作品をダウンロードしましょう")
                    )
                } else {
                    List {
                        ForEach(library.sortedBooks) { item in
                            NavigationLink(value: ReaderRoute(book: item.book)) {
                                LibraryRow(item: item)
                            }
                        }
                        .onDelete { offsets in
                            let books = library.sortedBooks
                            for offset in offsets {
                                library.delete(books[offset].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("本棚")
            .navigationDestination(for: ReaderRoute.self) { route in
                ReaderView(book: route.book)
            }
        }
    }
}

private struct LibraryRow: View {
    let item: LibraryBook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.book.displayTitle)
                .font(.headline)
            Text(item.book.displayCredit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ProgressView(value: item.progress)
                    .frame(maxWidth: 120)
                Text(item.progress == 0 ? "未読" : "\(Int((item.progress * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

/// 読書画面への遷移
struct ReaderRoute: Hashable {
    let book: CatalogBook
}
