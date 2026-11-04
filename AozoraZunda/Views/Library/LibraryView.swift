import SwiftUI

/// ずんだもんの部屋。歩いて本棚や机を調べ、ドアから図書館へ出かける
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(CatalogStore.self) private var catalog
    @Environment(StoryStore.self) private var story
    /// 図書館へ出かける
    let goToLibrary: () -> Void
    /// 夜まで待って、ストーリーの舞台の夜間図書室へ行く
    let goToNightLibrary: () -> Void

    @State private var path = NavigationPath()
    @State private var scene: RoomScene
    @State private var dialog: RoomDialog?
    @State private var tvAd = TVAdController()

    private static let bedLines = [
        "ふかふかのお布団なのだ。…でも、もう1ページだけ読むのだ",
        "ここで本を読んでいると、いつのまにか朝になっているのだ",
        "今日はたくさん歩いたのだ。おやすみなのだ…zzz",
        "まくらの下に読みかけの本をかくしているのは、ないしょなのだ",
    ]

    /// startsAtDoor: 図書館から帰ってきたときはドアの前から始める
    init(startsAtDoor: Bool = false, goToLibrary: @escaping () -> Void, goToNightLibrary: @escaping () -> Void) {
        self.goToLibrary = goToLibrary
        self.goToNightLibrary = goToNightLibrary
        _scene = State(initialValue: RoomScene(startsAtDoor: startsAtDoor))
    }

    var body: some View {
        NavigationStack(path: $path) {
            WalkGameView(
                scene: scene,
                idleMessage: "ずんだもんの部屋なのだ。行きたい場所をタップすると歩くのだ。下のドアから図書館へ行けるのだ",
                isInputEnabled: dialog == nil,
                showsBanner: true
            ) { interactable in
                interact(with: interactable)
            }
            .overlay {
                if let dialog {
                    DialogOverlay(dialog: dialog) { self.dialog = nil }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: dialog == nil)
            .onAppear {
                // テレビの広告は先に読み込んでおく。見終わったらずんだもんがひとこと
                tvAd.onDismiss = {
                    dialog = RoomDialog(text: "ふむふむ…なかなかおもしろかったのだ", choices: [close])
                }
                tvAd.load()
                offerStoryBookIfNeeded()
            }
            .task(id: library.sortedBooks.map(\.id)) {
                // 調べる前から冊数が分かるよう、部屋の本棚に持っている本を並べる
                scene.showBooks(library.sortedBooks.map(\.book))
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationTitle("へや")
            .navigationDestination(for: MyShelfRoute.self) { _ in
                MyShelfView(goToLibrary: goToLibrary)
            }
            .navigationDestination(for: CatalogBook.self) { book in
                BookDetailView(book: book)
            }
            .navigationDestination(for: ReaderRoute.self) { route in
                ReaderView(book: route.book)
            }
        }
    }

    private func interact(with interactable: RoomInteractable) {
        switch interactable {
        case .shelf:
            path.append(MyShelfRoute())
        case .desk:
            dialog = deskDialog()
        case .bed:
            dialog = RoomDialog(
                text: Self.bedLines.randomElement() ?? "",
                choices: [
                    GameChoice("夜まで まつ（ストーリー）") {
                        dialog = nil
                        goToNightLibrary()
                    },
                    close,
                ]
            )
        case .tv:
            dialog = tvDialog()
        case .door:
            goToLibrary()
        }
    }

    /// 章を終えた朝に、その章の本物の本を読んでみるかたずねる（章ごとに一度だけ）
    private static let storyBooks: [(cleared: StoryFlag, offered: StoryFlag, bookID: String, text: String)] = [
        (.chapter1Cleared, .chapter1ReadOffered, "001567", "……メロスの続きが気になって、あんまり眠れなかったのだ。本物の『走れメロス』、読んでみるのだ？"),
        (.chapter2Cleared, .chapter2ReadOffered, "000789", "……タマと読んだ『吾輩は猫である』、ほんとうはもっと長いのだ。本物、読んでみるのだ？"),
        (.chapter3Cleared, .chapter3ReadOffered, "000456", "……ジョバンニとカムパネルラ、あのあとどうなったのだ……。本物の『銀河鉄道の夜』、読んでみるのだ？"),
    ]

    private func offerStoryBookIfNeeded() {
        guard let offer = Self.storyBooks.first(where: { story.has($0.cleared) && !story.has($0.offered) }) else { return }
        story.set(offer.offered)
        dialog = RoomDialog(
            text: offer.text,
            choices: [
                GameChoice("よむ") {
                    dialog = nil
                    Task { await openStoryBook(id: offer.bookID) }
                },
                GameChoice("あとにする") { dialog = nil },
            ]
        )
    }

    private func openStoryBook(id: String) async {
        await catalog.loadIfNeeded()
        if let book = catalog.books.first(where: { $0.id == id }) {
            path.append(book)
        } else {
            dialog = RoomDialog(text: "本が見つからなかったのだ……。図書館の司書さんに聞いてみるのだ", choices: [close])
        }
    }

    /// 最後に開いた読みかけの本のつづきをすすめる
    private func deskDialog() -> RoomDialog {
        let reading = library.books
            .filter { $0.lastOpenedAt != nil && !MyShelfView.isFinished($0) }
            .max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
        guard let reading else {
            return RoomDialog(text: "読みかけの本はないのだ。本棚から読みたい本をえらぶのだ", choices: [close])
        }
        let percent = Int((reading.progress * 100).rounded())
        return RoomDialog(
            text: "『\(reading.book.displayTitle)』を\(percent)%まで読んでいたのだ。つづきを読むのだ？",
            choices: [
                GameChoice("よむ") {
                    dialog = nil
                    path.append(ReaderRoute(book: reading.book))
                },
                GameChoice("あとにする") { dialog = nil },
            ]
        )
    }

    /// テレビで流れている広告を見るか聞く。まだ読み込めていなければ何も映っていない
    private func tvDialog() -> RoomDialog {
        guard tvAd.isReady else {
            tvAd.load()
            return RoomDialog(text: "今は何も映っていないのだ…。あとでまた見てみるのだ", choices: [close])
        }
        return RoomDialog(
            text: "テレビで広告が流れているのだ。内容を見てみるのだ？",
            choices: [
                GameChoice("みる") {
                    dialog = nil
                    if !tvAd.present() {
                        dialog = RoomDialog(text: "あれ、映らなくなっちゃったのだ…", choices: [close])
                    }
                },
                GameChoice("やめておく") { dialog = nil },
            ]
        )
    }

    private var close: GameChoice {
        GameChoice("とじる") { dialog = nil }
    }
}

private struct MyShelfRoute: Hashable {}

/// 部屋で机やベッドを調べたときの、ずんだもんのひとこと
private struct RoomDialog {
    let text: String
    let choices: [GameChoice]
}

private struct DialogOverlay: View {
    let dialog: RoomDialog
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 10) {
                Text(dialog.text)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(dialog.choices.enumerated()), id: \.offset) { _, choice in
                        GameChoiceView(choice: choice)
                    }
                }
            }
            .gameWindowStyle()
            .speakerName("ずんだもん")
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

/// 読書画面への遷移
struct ReaderRoute: Hashable {
    let book: CatalogBook
}
