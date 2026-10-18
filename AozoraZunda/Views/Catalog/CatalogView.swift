import SwiftUI

/// 青空文庫の作品をさがす画面。図書館の中を歩いて本棚や司書さんを調べる
struct CatalogView: View {
    @Environment(CatalogStore.self) private var catalog
    /// ずんだもんの部屋へ帰る
    let goToRoom: () -> Void
    @State private var path = NavigationPath()
    @State private var scene = LibraryScene()

    var body: some View {
        NavigationStack(path: $path) {
            WalkGameView(scene: scene, idleMessage: "画面をドラッグして歩こう。本棚や司書さんの前で「しらべる」。下の入口から部屋に帰れる", showsBanner: true) { interactable in
                switch interactable {
                case .shelf(let label):
                    path.append(ShelfRoute(label: label))
                case .librarian:
                    path.append(SearchRoute())
                case .exit:
                    goToRoom()
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationTitle("としょかん")
            .navigationDestination(for: ShelfRoute.self) { route in
                BookshelfView(label: route.label, initialAuthorID: route.authorID)
            }
            .navigationDestination(for: SearchRoute.self) { _ in
                LibrarianView()
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

struct ShelfRoute: Hashable {
    let label: String
    /// 指定すると、その作家の仕切り板の段から表示する
    var authorID: String?
}

private struct SearchRoute: Hashable {}

/// 作品一覧の取得が終わるまでは読み込み中・エラーを表示する
struct CatalogContent<Content: View>: View {
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
