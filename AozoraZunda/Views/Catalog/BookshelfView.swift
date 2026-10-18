import SwiftUI

/// かな行ごとの本棚。作品を背表紙で並べ、作家ごとに仕切り板を入れる
struct BookshelfView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(LibraryStore.self) private var library
    let label: String
    /// 司書さんに案内されたときは、この作家の仕切り板の段から表示する
    var initialAuthorID: String?

    @State private var selection: ShelfItem.ID?
    @State private var readingBook: CatalogBook?
    @State private var errorMessage: String?

    var body: some View {
        CatalogContent {
            let authors = catalog.authorSections.first { $0.title == label }?.authors ?? []
            if authors.isEmpty {
                ContentUnavailableView("この棚には本がありません", systemImage: "books.vertical")
            } else {
                shelf(authors: authors)
            }
        }
        .background(ShelfPalette.back)
        .navigationTitle("「\(label)」の棚")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ShelfPalette.frame, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $readingBook) { book in
            ReaderView(book: book)
        }
    }

    private func shelf(authors: [CatalogAuthor]) -> some View {
        let items = authors.flatMap { author in
            [ShelfItem.divider(author)] + catalog.works(byAuthor: author.id).map { ShelfItem.book($0, authorID: author.id) }
        }
        let selected = items.first { $0.id == selection }

        return GeometryReader { geometry in
            let rows = ShelfLayout.rows(of: items, width: geometry.size.width - ShelfLayout.indexWidth - ShelfLayout.sideInset * 2)
            let jumps = ShelfLayout.jumpTargets(in: rows)
            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(rows.indices, id: \.self) { index in
                                ShelfRow(items: rows[index], selection: $selection) { book in
                                    library.isDownloaded(book.id) ? .downloaded : .none
                                }
                                    .id(index)
                                if ShelfLayout.isAdRow(after: index) {
                                    NativeAdShelfRow()
                                }
                            }
                            Color.clear.frame(height: 24)
                        }
                        .padding(.horizontal, ShelfLayout.sideInset)
                    }
                    .scrollIndicators(.hidden)
                    InitialIndex(entries: jumps) { row in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(row, anchor: .top)
                        }
                    }
                    .frame(width: ShelfLayout.indexWidth)
                }
                // 本はウインドウの下に隠れながらスクロールし、索引で移動したときはウインドウのすぐ下に来る
                .safeAreaInset(edge: .top) {
                    window(for: selected, authorCount: authors.count, bookCount: items.count - authors.count)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .task {
                    guard let initialAuthorID,
                          let row = rows.firstIndex(where: { $0.contains { $0.id == ShelfItem.divider(id: initialAuthorID) } })
                    else { return }
                    proxy.scrollTo(row, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func window(for item: ShelfItem?, authorCount: Int, bookCount: Int) -> some View {
        if case .book(let book, _) = item {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(book.displayCredit)『\(book.displayTitle)』")
                    .lineLimit(2)
                if library.isDownloading(book.id) {
                    Text("本をとりよせています…")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color(red: 1, green: 0.7, blue: 0.7))
                }
                HStack(spacing: 20) {
                    WindowChoice(title: "よむ") { read(book) }
                        .disabled(library.isDownloading(book.id))
                    NavigationLink(value: book) {
                        ChoiceLabel(title: "しらべる")
                    }
                    .buttonStyle(.plain)
                    WindowChoice(title: "もどす") { select(nil) }
                }
            }
            .gameWindowStyle()
        } else {
            Text("「\(label)」の棚 ── \(authorCount)人の作家の本が\(bookCount)冊並んでいる。背表紙をタップして手に取ろう")
                .gameWindowStyle()
        }
    }

    private func select(_ id: ShelfItem.ID?) {
        errorMessage = nil
        withAnimation(.spring(duration: 0.25)) {
            selection = id
        }
    }

    private func read(_ book: CatalogBook) {
        if library.isDownloaded(book.id) {
            readingBook = book
            return
        }
        Task {
            errorMessage = nil
            do {
                try await library.download(book)
                readingBook = book
            } catch {
                errorMessage = "とりよせられませんでした: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 並べ方

enum ShelfItem: Identifiable {
    case divider(CatalogAuthor)
    /// 共著の作品は複数の作家の棚に並ぶので、ID には作家も含める
    case book(CatalogBook, authorID: String)

    static func divider(id authorID: String) -> String {
        "author-\(authorID)"
    }

    var id: String {
        switch self {
        case .divider(let author): Self.divider(id: author.id)
        case .book(let book, let authorID): "book-\(authorID)-\(book.id)"
        }
    }

    var width: CGFloat {
        switch self {
        case .divider: ShelfLayout.dividerWidth
        case .book: ShelfLayout.spineWidth
        }
    }
}

enum ShelfLayout {
    static let spineWidth: CGFloat = 26
    static let dividerWidth: CGFloat = 30
    static let spacing: CGFloat = 2
    static let sideInset: CGFloat = 10
    static let indexWidth: CGFloat = 22
    static let rowHeight: CGFloat = 152
    /// 段の内側の左右の余白
    static let rowInset: CGFloat = 10

    /// 棚の幅に収まるように左から詰めて段に分ける
    static func rows(of items: [ShelfItem], width: CGFloat) -> [[ShelfItem]] {
        let usable = max(width - rowInset * 2, spineWidth)
        var rows: [[ShelfItem]] = []
        var current: [ShelfItem] = []
        var used: CGFloat = 0
        for item in items {
            let needed = item.width + (current.isEmpty ? 0 : spacing)
            if used + needed > usable, !current.isEmpty {
                rows.append(current)
                current = []
                used = 0
            }
            used += item.width + (current.isEmpty ? 0 : spacing)
            current.append(item)
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    /// 広告の段を入れる間隔（本を探す邪魔にならないよう、20段に1つ）
    static let adRowInterval = 20

    /// この段のあとに広告の段を入れるか（最初は6段目のあと）
    static func isAdRow(after index: Int) -> Bool {
        index % adRowInterval == 5
    }

    /// 作家の頭文字ごとに、最初の仕切り板がある段
    static func jumpTargets(in rows: [[ShelfItem]]) -> [(initial: String, row: Int)] {
        var targets: [(initial: String, row: Int)] = []
        for (index, row) in rows.enumerated() {
            for case .divider(let author) in row {
                let initial = String(author.sortKey.prefix(1))
                if targets.last?.initial != initial {
                    targets.append((initial, index))
                }
            }
        }
        return targets
    }
}

// MARK: - 見た目

enum ShelfPalette {
    static let back = Color(red: 0.24, green: 0.16, blue: 0.10)
    static let frame = Color(red: 0.35, green: 0.23, blue: 0.15)
    static let plank = Color(red: 0.54, green: 0.35, blue: 0.21)
    static let plankLight = Color(red: 0.81, green: 0.60, blue: 0.38)
    static let outline = Color(red: 0.17, green: 0.12, blue: 0.10)
    static let divider = Color(red: 0.91, green: 0.86, blue: 0.75)
    static let board = Color(red: 0.81, green: 0.60, blue: 0.38)
    static let boardInk = Color(red: 0.24, green: 0.14, blue: 0.08)
    static let highlight = Color(red: 1.0, green: 0.90, blue: 0.50)
    static let ribbon = Color(red: 0.85, green: 0.20, blue: 0.25)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.30)
    /// ドット絵の本棚と同じ色
    static let spines: [(Color, Color)] = [
        (Color(red: 0.72, green: 0.29, blue: 0.29), .white),
        (Color(red: 0.29, green: 0.45, blue: 0.72), .white),
        (Color(red: 0.37, green: 0.64, blue: 0.35), .white),
        (Color(red: 0.85, green: 0.64, blue: 0.25), Color(red: 0.23, green: 0.14, blue: 0.08)),
        (Color(red: 0.54, green: 0.35, blue: 0.68), .white),
        (Color(red: 0.24, green: 0.61, blue: 0.60), .white),
        (Color(red: 0.88, green: 0.49, blue: 0.31), .white),
        (Color(red: 0.25, green: 0.30, blue: 0.45), .white),
    ]

    /// 作品の背表紙の色と文字色。どの画面でも同じ作品は同じ色になる
    static func spine(for book: CatalogBook) -> (color: Color, ink: Color) {
        spines[book.spineSeed % spines.count]
    }
}

/// 棚の1段。本の下に棚板を描く
struct ShelfRow: View {
    let items: [ShelfItem]
    @Binding var selection: ShelfItem.ID?
    /// 背表紙に付ける印
    let mark: (CatalogBook) -> SpineMark

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: ShelfLayout.spacing) {
                ForEach(items) { item in
                    switch item {
                    case .divider(let author):
                        AuthorDivider(author: author)
                    case .book(let book, _):
                        BookSpine(book: book, isSelected: selection == item.id, mark: mark(book)) {
                            withAnimation(.spring(duration: 0.25)) {
                                selection = selection == item.id ? nil : item.id
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ShelfLayout.rowInset - 4)
            .frame(height: ShelfLayout.rowHeight - 14, alignment: .bottom)
            .background(ShelfPalette.back.shadow(.inner(color: .black.opacity(0.5), radius: 0, y: 6)))

            Rectangle()
                .fill(ShelfPalette.plank)
                .frame(height: 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(ShelfPalette.plankLight).frame(height: 3)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ShelfPalette.outline).frame(height: 3)
                }
        }
        .padding(.horizontal, 4)
        .background(ShelfPalette.frame)
    }
}

/// 背表紙に付ける印
enum SpineMark {
    case none
    /// 挟んだしおり
    case ribbon(String)
    /// 背表紙に巻いた金色の帯
    case band(String)

    static let downloaded = SpineMark.ribbon("ダウンロード済み")

    var accessibilityValue: String {
        switch self {
        case .none: ""
        case .ribbon(let label), .band(let label): label
        }
    }
}

/// 作品の背表紙。色と高さは作品ごとに決まっていて毎回同じになる
struct BookSpine: View {
    let book: CatalogBook
    let isSelected: Bool
    var mark = SpineMark.none
    let action: () -> Void

    var body: some View {
        let (color, ink) = ShelfPalette.spine(for: book)
        let height = 96 + CGFloat(book.spineSeed / 7 % 6) * 6

        Button(action: action) {
            VerticalText(text: book.title, maxLength: Int((height - 18) / 12))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .padding(.top, 8)
                .frame(width: ShelfLayout.spineWidth, height: height, alignment: .top)
                // 画面の端に接していても色を安全領域まで伸ばさない
                .background(color, ignoresSafeAreaEdges: [])
                .overlay(alignment: .bottom) {
                    // 背表紙の下の帯
                    Rectangle().fill(.black.opacity(0.18)).frame(height: 6).padding(.bottom, 6)
                }
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                        .strokeBorder(isSelected ? ShelfPalette.highlight : ShelfPalette.outline, lineWidth: 2)
                }
                .overlay(alignment: .top) {
                    switch mark {
                    case .none:
                        EmptyView()
                    case .ribbon:
                        Rectangle()
                            .fill(ShelfPalette.ribbon)
                            .frame(width: 5, height: 14)
                            .offset(x: 5, y: -8)
                    case .band:
                        Rectangle()
                            .fill(ShelfPalette.gold)
                            .frame(height: 4)
                            .padding(.top, height - 24)
                    }
                }
        }
        .buttonStyle(.plain)
        .offset(y: isSelected ? -14 : 0)
        .shadow(color: isSelected ? ShelfPalette.highlight.opacity(0.6) : .clear, radius: 6)
        .zIndex(isSelected ? 1 : 0)
        .accessibilityLabel("\(book.displayTitle)、\(book.displayCredit)")
        .accessibilityValue(mark.accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension CatalogBook {
    /// 背表紙の色や高さを決める、作品IDから決まる値（起動のたびに変わらないよう hashValue は使わない）
    var spineSeed: Int {
        Int(id) ?? id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) } & .max
    }
}

/// 作家名を書いた仕切り板
private struct AuthorDivider: View {
    let author: CatalogAuthor

    var body: some View {
        VerticalText(text: author.name, maxLength: 10)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(ShelfPalette.boardInk)
            .padding(.top, 10)
            .frame(width: ShelfLayout.dividerWidth, height: 136, alignment: .top)
            .background(ShelfPalette.board, in: UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6))
            .overlay(alignment: .top) {
                // 名札を留める鋲
                Circle().fill(ShelfPalette.boardInk).frame(width: 4, height: 4).padding(.top, 3)
            }
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                    .strokeBorder(ShelfPalette.outline, lineWidth: 2)
            }
            .accessibilityElement()
            .accessibilityLabel("\(author.name)の本")
            .accessibilityAddTraits(.isHeader)
    }
}

/// 1文字ずつ縦に並べる簡易的な縦書き。長いものは末尾を「…」で省略する
private struct VerticalText: View {
    let text: String
    let maxLength: Int

    var body: some View {
        let characters = Self.verticalForms(text)
        let shown = characters.count > maxLength ? Array(characters.prefix(maxLength - 1)) + ["︙"] : characters
        VStack(spacing: -1) {
            ForEach(shown.indices, id: \.self) { index in
                Text(shown[index])
            }
        }
        .accessibilityHidden(true)
    }

    /// 縦書きで向きが変わる記号を縦書き用の字形に置き換える
    private static func verticalForms(_ text: String) -> [String] {
        let map: [Character: String] = [
            "ー": "丨", "−": "丨", "-": "丨", "―": "丨", "…": "︙", "、": "︑", "。": "︒",
            "（": "︵", "）": "︶", "(": "︵", ")": "︶", "「": "﹁", "」": "﹂", "『": "﹃", "』": "﹄",
            "〈": "︿", "〉": "﹀", "《": "︽", "》": "︾", "〜": "≀", "～": "≀", "：": "︰", " ": "", "　": "",
        ]
        return text.compactMap { character in
            let form = map[character] ?? String(character)
            return form.isEmpty ? nil : form
        }
    }
}

/// 右端の頭文字の索引。タップかなぞると、その頭文字の作家の段まで移動する
private struct InitialIndex: View {
    let entries: [(initial: String, row: Int)]
    let jump: (Int) -> Void

    @State private var current: String?

    var body: some View {
        GeometryReader { geometry in
            let itemHeight = min(22, geometry.size.height * 0.7 / CGFloat(max(entries.count, 1)))
            VStack(spacing: 0) {
                ForEach(entries, id: \.initial) { entry in
                    Text(entry.initial)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(current == entry.initial ? ShelfPalette.highlight : ShelfPalette.divider)
                        .frame(width: ShelfLayout.indexWidth, height: itemHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let top = (geometry.size.height - itemHeight * CGFloat(entries.count)) / 2
                        let index = Int((value.location.y - top) / itemHeight)
                        guard entries.indices.contains(index), entries[index].initial != current else { return }
                        current = entries[index].initial
                        jump(entries[index].row)
                    }
                    .onEnded { _ in current = nil }
            )
        }
        .background(ShelfPalette.frame)
        .accessibilityHidden(true)
    }
}
