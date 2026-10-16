import SwiftUI

/// 司書さんと会話しながら本をさがす画面
struct LibrarianView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = Step.greeting
    @State private var query = ""
    @State private var selectedBookID: CatalogBook.ID?
    @State private var readingBook: CatalogBook?
    @State private var errorMessage: String?
    /// セリフを1文字ずつ表示するための状態
    @State private var typedLine = ""
    @State private var typedCount = 0
    @FocusState private var isInputFocused: Bool

    private static let maxAuthorChoices = 6

    private enum SearchKind {
        case title, author
    }

    private enum Step: Equatable {
        case greeting
        case ask(SearchKind)
        case titles(query: String, books: [CatalogBook])
        case authors(query: String, authors: [CatalogAuthor])
        case author(CatalogAuthor)
        case notFound(SearchKind, query: String)
        case recommend(CatalogBook)
        case refreshing
        case refreshed(succeeded: Bool)
    }

    var body: some View {
        CatalogContent {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LibrarianFigure(isTalking: isTyping)
                if !counterBooks.isEmpty {
                    BookCart(books: counterBooks, selectedID: selectedBookID) { book in
                        withAnimation(.spring(duration: 0.25)) {
                            selectedBookID = selectedBookID == book.id ? nil : book.id
                        }
                        errorMessage = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom) {
                dialogue
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .background(LibrarianRoom())
        .navigationTitle("司書さん")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ShelfPalette.frame, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $readingBook) { book in
            ReaderView(book: book)
        }
        .task(id: line) {
            await typeLine()
        }
    }

    // MARK: - セリフと選択肢

    private var selectedBook: CatalogBook? {
        counterBooks.first { $0.id == selectedBookID }
    }

    /// カウンターに出してもらった本
    private var counterBooks: [CatalogBook] {
        switch step {
        case .titles(_, let books): books
        case .recommend(let book): [book]
        default: []
        }
    }

    private var line: String {
        switch step {
        case .greeting:
            return "いらっしゃい。どんな本をおさがし？"
        case .ask(.title):
            return "題名を教えてね。ひらがなでも大丈夫よ。"
        case .ask(.author):
            return "作家さんの名前を教えてね。ひらがなでも大丈夫よ。"
        case .titles(let query, let books):
            if let selectedBook {
                return "\(selectedBook.displayCredit)『\(selectedBook.displayTitle)』ね。どうする？"
            }
            let found = books.count > 100 ? "\(books.count)冊もあったわ。" : "\(books.count)冊見つかったわ。"
            return "「\(query)」なら\(found)気になる本をえらんでね。"
        case .authors(let query, let authors):
            if authors.count > Self.maxAuthorChoices {
                return "「\(query)」だと\(authors.count)人もいるわ。近いのはこのあたりかしら？"
            }
            return "「\(query)」なら\(authors.count)人いるわ。どの作家さん？"
        case .author(let author):
            let label = catalog.shelfLabel(ofAuthor: author.id) ?? "他"
            return "\(author.name)さんの本なら「\(label)」の棚に\(author.workCount)冊あるわ。案内しましょうか？"
        case .notFound(_, let query):
            return "うーん、「\(query)」の本は見つからないなあ…。"
        case .recommend(let book):
            return "今日はこれなんてどう？\n\(book.displayCredit)『\(book.displayTitle)』よ。"
        case .refreshing:
            return "目録を新しくしているわ。ちょっと待っててね…"
        case .refreshed(succeeded: true):
            return "新しくしたわ！いまは全部で\(catalog.books.count)冊あるのよ。"
        case .refreshed(succeeded: false):
            return "ごめんなさい、うまくいかなかったみたい…。電波のいいところでもう一度ためしてね。"
        }
    }

    private var choices: [GameChoice] {
        let anotherWord = GameChoice("ほかの言葉でさがす") { go(.ask(kind)) }
        let enough = GameChoice("もういい") { dismiss() }
        switch step {
        case .greeting:
            return [
                GameChoice("題名でさがす") { go(.ask(.title)) },
                GameChoice("作家でさがす") { go(.ask(.author)) },
                GameChoice("おまかせで1冊") { recommend() },
                GameChoice("目録を新しくして") { refresh() },
                GameChoice("なんでもない") { dismiss() },
            ]
        case .ask:
            return [GameChoice("やっぱりいい") { go(.greeting) }]
        case .titles:
            if let selectedBook {
                return bookChoices(for: selectedBook) + [anotherWord, enough]
            }
            return [anotherWord, enough]
        case .authors(_, let authors):
            return authors.prefix(Self.maxAuthorChoices).map { author in
                GameChoice(author.name) { go(.author(author)) }
            } + [anotherWord]
        case .author(let author):
            let label = catalog.shelfLabel(ofAuthor: author.id) ?? "他"
            return [
                GameChoice("案内してもらう", route: ShelfRoute(label: label, authorID: author.id)),
                GameChoice("ほかの作家をさがす") { go(.ask(.author)) },
                enough,
            ]
        case .notFound:
            return [anotherWord, GameChoice("おまかせで1冊") { recommend() }, enough]
        case .recommend(let book):
            return bookChoices(for: book) + [GameChoice("ほかのにする") { recommend() }, enough]
        case .refreshing:
            return []
        case .refreshed:
            return [GameChoice("ほかにも用がある") { go(.greeting) }, enough]
        }
    }

    private func bookChoices(for book: CatalogBook) -> [GameChoice] {
        [
            GameChoice("よむ", isEnabled: !library.isDownloading(book.id)) { read(book) },
            GameChoice("しらべる", book: book),
        ]
    }

    /// 直前にさがした方法（言いなおすときに同じ方法でたずねる）
    private var kind: SearchKind {
        switch step {
        case .ask(let kind), .notFound(let kind, _): kind
        case .authors, .author: .author
        default: .title
        }
    }

    // MARK: - ウインドウ

    private var isTyping: Bool {
        typedLine != line || typedCount < line.count
    }

    private var dialogue: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                // 全文で高さを確保しておき、表示した分だけ重ねる
                Text(line).hidden()
                Text(typedLine == line ? String(line.prefix(typedCount)) : "")
            }
            .accessibilityElement()
            .accessibilityLabel(line)

            if let status {
                Text(status)
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.6))
            }

            if !isTyping {
                if case .ask = step {
                    inputField
                }
                VStack(alignment: .leading, spacing: 2) {
                    // 同姓同名の作家もいるので並び順で区別する
                    ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                        GameChoiceView(choice: choice)
                    }
                }
                .transition(.opacity)
            }
        }
        .gameWindowStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            // タップでセリフを最後まで表示する
            typedLine = line
            typedCount = line.count
        }
        .speakerName("司書さん")
        .animation(.easeOut(duration: 0.15), value: isTyping)
    }

    private var status: String? {
        if let selectedBook = selectedBook ?? recommendedBook, library.isDownloading(selectedBook.id) {
            return "（本をとりよせています…）"
        }
        return errorMessage
    }

    private var recommendedBook: CatalogBook? {
        if case .recommend(let book) = step { book } else { nil }
    }

    private var inputField: some View {
        TextField(kind == .title ? "題名・よみがな" : "作家名・よみがな", text: $query)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white, in: RoundedRectangle(cornerRadius: 4))
            .submitLabel(.search)
            .focused($isInputFocused)
            .onSubmit { search() }
            .onAppear { isInputFocused = true }
    }

    // MARK: - 動作

    private func typeLine() async {
        let target = line
        typedLine = target
        if reduceMotion {
            typedCount = target.count
            return
        }
        typedCount = 0
        while typedCount < target.count {
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            typedCount += 1
        }
    }

    private func go(_ next: Step) {
        errorMessage = nil
        withAnimation(.spring(duration: 0.3)) {
            selectedBookID = nil
            step = next
        }
    }

    private func search() {
        let words = query.trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return }
        isInputFocused = false
        switch kind {
        case .title:
            let books = catalog.searchTitles(words)
            go(books.isEmpty ? .notFound(.title, query: words) : .titles(query: words, books: books))
        case .author:
            let authors = catalog.searchAuthors(words)
            switch authors.count {
            case 0: go(.notFound(.author, query: words))
            case 1: go(.author(authors[0]))
            default: go(.authors(query: words, authors: authors))
            }
        }
    }

    private func recommend() {
        guard let book = catalog.books.randomElement() else { return }
        go(.recommend(book))
        selectedBookID = book.id
    }

    private func refresh() {
        go(.refreshing)
        let before = catalog.updatedAt
        Task {
            await catalog.refresh()
            // 失敗しても手元の一覧は使い続けるので、更新日時が変わったかで成否を判断する
            go(.refreshed(succeeded: catalog.updatedAt != before))
        }
    }

    private func read(_ book: CatalogBook) {
        Task {
            errorMessage = nil
            do {
                // ダウンロード済みなら何もしない
                try await library.download(book)
                readingBook = book
            } catch {
                errorMessage = "とりよせられなかったわ…（\(error.localizedDescription)）"
            }
        }
    }
}

// MARK: - 背景と司書さん

/// 本棚の並ぶ壁と床
private struct LibrarianRoom: View {
    var body: some View {
        GeometryReader { geometry in
            let shelfSize: CGFloat = 96
            VStack(spacing: 0) {
                let wallHeight = geometry.size.height * 0.4
                // 壁一面に本棚を積み上げる（下の段から並べ、上ではみ出た分は切る）
                VStack(spacing: 0) {
                    ForEach(0..<(Int(wallHeight / shelfSize) + 1), id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<(Int(geometry.size.width / shelfSize) + 1), id: \.self) { column in
                                PixelImage(name: "sprite_bookshelf_\((row * 3 + column) % 4)")
                                    .frame(width: shelfSize, height: shelfSize)
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width, height: wallHeight, alignment: .bottomLeading)
                .clipped()
                .background(Color(red: 0.35, green: 0.23, blue: 0.15))
                Color(red: 0.79, green: 0.64, blue: 0.48)
            }
        }
        .ignoresSafeArea()
    }
}

/// カウンターの向こうに立つ司書さん。ときどきまばたきし、話している間は小さく揺れる
private struct LibrarianFigure: View {
    let isTalking: Bool

    @State private var isBlinking = false
    @State private var bounce = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PixelImage(name: isBlinking ? "sprite_librarian_idle2" : "sprite_librarian_idle1")
                .frame(width: 128, height: 128)
                .offset(y: (bounce ? -4 : 0) - 70)
            PixelImage(name: "sprite_counter")
                .frame(width: 240, height: 120)
        }
        .frame(height: 190, alignment: .bottom)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2...4)))
                isBlinking = true
                try? await Task.sleep(for: .milliseconds(150))
                isBlinking = false
            }
        }
        .task(id: isTalking) {
            while isTalking, !Task.isCancelled {
                bounce.toggle()
                try? await Task.sleep(for: .milliseconds(140))
            }
            bounce = false
        }
    }
}

/// ドット絵をにじませずに拡大する
private struct PixelImage: View {
    let name: String

    var body: some View {
        Image(name)
            .interpolation(.none)
            .resizable()
    }
}

/// 司書さんが出してくれた本を並べる台
private struct BookCart: View {
    @Environment(LibraryStore.self) private var library
    let books: [CatalogBook]
    let selectedID: CatalogBook.ID?
    let select: (CatalogBook) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(books.enumerated()), id: \.offset) { _, book in
                    BookSpine(book: book, isSelected: book.id == selectedID, mark: library.isDownloaded(book.id) ? .downloaded : .none) {
                        select(book)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .frame(height: 160)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(ShelfPalette.plank)
                .frame(height: 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(ShelfPalette.plankLight).frame(height: 3)
                }
        }
    }
}
