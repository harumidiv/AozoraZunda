import SwiftUI

/// ずんだもんの部屋の本棚。ダウンロードした本を最近読んだ順に背表紙で並べる
struct MyShelfView: View {
    @Environment(LibraryStore.self) private var library
    let goToLibrary: () -> Void

    @State private var selection: ShelfItem.ID?
    @State private var returningBook: LibraryBook?

    /// 本が少なくても本棚らしく見えるよう、最低限並べる段の数
    private static let minimumRows = 3

    var body: some View {
        let books = library.sortedBooks
        let items = books.map { ShelfItem.book($0.book, authorID: $0.book.authorID) }
        let selected = books.first { ShelfItem.book($0.book, authorID: $0.book.authorID).id == selection }

        GeometryReader { geometry in
            let rows = ShelfLayout.rows(of: items, width: geometry.size.width - ShelfLayout.sideInset * 2)
            let paddedRows = rows + Array(repeating: [], count: max(0, Self.minimumRows - rows.count))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(paddedRows.indices, id: \.self) { index in
                        ShelfRow(items: paddedRows[index], selection: $selection) { book in
                            Self.mark(for: library.libraryBook(for: book.id))
                        }
                    }
                }
                .padding(.horizontal, ShelfLayout.sideInset)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                window(books: books, selected: selected)
                    .padding(.horizontal)
                    // 名札がナビゲーションバーに隠れないぶん上を広めに空ける
                    .padding(.top, 18)
                    .padding(.bottom, 8)
            }
        }
        .background(ShelfPalette.back)
        .navigationTitle("ずんだもんの本棚")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ShelfPalette.frame, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "図書館にかえすのだ？",
            isPresented: Binding(get: { returningBook != nil }, set: { if !$0 { returningBook = nil } }),
            titleVisibility: .visible,
            presenting: returningBook
        ) { item in
            Button("『\(item.book.title)』をかえす", role: .destructive) {
                withAnimation {
                    selection = nil
                    library.delete(item.id)
                }
            }
        } message: { _ in
            Text("読んだところまでの記録も消えるのだ。また読みたくなったら図書館で借りられるのだ")
        }
    }

    @ViewBuilder
    private func window(books: [LibraryBook], selected: LibraryBook?) -> some View {
        if let selected {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(selected.book.displayCredit)『\(selected.book.displayTitle)』 ── \(Self.progressText(of: selected))")
                    .lineLimit(3)
                VStack(alignment: .leading, spacing: 2) {
                    GameChoiceView(choice: GameChoice(Self.readTitle(of: selected), reader: ReaderRoute(book: selected.book)))
                    GameChoiceView(choice: GameChoice("しらべる", book: selected.book))
                    GameChoiceView(choice: GameChoice("図書館にかえす") { returningBook = selected })
                    GameChoiceView(choice: GameChoice("もどす") {
                        withAnimation(.spring(duration: 0.25)) { selection = nil }
                    })
                }
            }
            .gameWindowStyle()
            .speakerName("ずんだもん")
        } else if books.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("まだ本がないのだ。図書館で借りてくるのだ！")
                GameChoiceView(choice: GameChoice("図書館へいく", action: goToLibrary))
            }
            .gameWindowStyle()
            .speakerName("ずんだもん")
        } else {
            let reading = books.count { $0.progress > 0 && !Self.isFinished($0) }
            let finished = books.count(where: Self.isFinished)
            Text("ずんだもんの本棚 ── \(books.count)冊。読みかけ\(reading)冊・読了\(finished)冊なのだ。背表紙をタップして手に取るのだ")
                .gameWindowStyle()
        }
    }

    // MARK: - 読み具合

    static func isFinished(_ item: LibraryBook) -> Bool {
        item.progress >= 0.99
    }

    static func progressText(of item: LibraryBook) -> String {
        if isFinished(item) { return "読み終わったのだ！" }
        if item.progress == 0 { return "まだ読んでないのだ" }
        return "\(Int((item.progress * 100).rounded()))%まで読んだのだ"
    }

    private static func readTitle(of item: LibraryBook) -> String {
        if isFinished(item) { return "もういちどよむ" }
        return item.progress == 0 ? "よむ" : "つづきをよむ"
    }

    /// 読みかけはしおり、読み終わった本は金色の帯
    private static func mark(for item: LibraryBook?) -> SpineMark {
        guard let item, item.progress > 0 else { return .none }
        if isFinished(item) { return .band("読了") }
        return .ribbon("\(Int((item.progress * 100).rounded()))%まで読んだ")
    }
}
