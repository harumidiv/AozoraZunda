import SwiftUI

/// 雨の夜だけ開く図書室。歩き回って幽霊と話し、ストーリーを進める。
/// 第1章からは、本の中（『走れメロス』の世界）にも入る
struct NightLibraryView: View {
    let story: StoryStore
    /// ずんだもんの部屋へ帰る
    let leave: () -> Void

    @State private var scene: NightLibraryScene
    @State private var runner: StoryRunner
    @State private var showsItems = false
    /// 開いている本の中のマップ（本の中にいないときは nil）
    @State private var melosScene: MelosScene?

    init(story: StoryStore, leave: @escaping () -> Void) {
        self.story = story
        self.leave = leave
        _scene = State(initialValue: NightLibraryScene(flags: story.flags))
        let runner = StoryRunner()
        // 章のはじめは、真っ暗な画面の語りや見出しから始める
        let startsChapter = !story.has(.prologueMetFumi) || (story.has(.prologueCleared) && !story.has(.chapter1Started))
        runner.setBlackedOut(startsChapter)
        _runner = State(initialValue: runner)
    }

    /// 序章を遊んでいる最中か（終わっていれば第1章）
    private var isPrologue: Bool { !story.has(.prologueCleared) }

    private var prologue: PrologueEvents {
        PrologueEvents(runner: runner, story: story, scene: scene, leave: leave)
    }

    private var chapter1: Chapter1Events {
        let runner = runner
        let story = story
        return Chapter1Events(
            runner: runner,
            story: story,
            library: scene,
            openBook: { [self] in
                let book = MelosScene(flags: story.flags)
                book.onTimeUp = { [self] in
                    let chapter1 = chapter1
                    runner.run { await chapter1.timeUp() }
                }
                melosScene = book
                return book
            },
            closeBook: { [self] in melosScene = nil },
            book: { [self] in melosScene },
            leave: leave
        )
    }

    private var isInputEnabled: Bool { !runner.isRunning && !showsItems }

    var body: some View {
        Group {
            if let melosScene {
                WalkGameView(
                    scene: melosScene,
                    idleMessage: Chapter1Events.bookObjective(story, clock: melosScene.clock),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInBook(with: interactable)
                }
                .overlay(alignment: .topTrailing) {
                    SunMeter(clock: melosScene.clock)
                        .padding(.top, 64)
                        .padding(.trailing, 16)
                        .allowsHitTesting(false)
                }
            } else {
                WalkGameView(
                    scene: scene,
                    idleMessage: isPrologue ? PrologueEvents.objective(story) : Chapter1Events.objective(story),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interact(with: interactable)
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if isInputEnabled {
                Button {
                    showsItems = true
                } label: {
                    Text("もちもの")
                        .font(.pixel(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RetroWindowBackground())
                }
                .buttonStyle(.plain)
                .padding(.leading, 24)
                .padding(.bottom, 16)
            }
        }
        .overlay {
            if showsItems {
                ItemListView(items: story.items) { showsItems = false }
            }
        }
        .overlay {
            StoryOverlay(runner: runner)
        }
        .onAppear {
            if isPrologue {
                let prologue = prologue
                runner.run { await prologue.arrive() }
            } else {
                let chapter1 = chapter1
                runner.run { await chapter1.arrive() }
            }
        }
        .onChange(of: runner.isRunning) { _, isRunning in
            // 会話や演出のあいだは、日没までの時間を止める
            melosScene?.isClockRunning = !isRunning
        }
    }

    private func interact(with interactable: NightLibraryInteractable) {
        let prologue = prologue
        let chapter1 = chapter1
        let isPrologue = isPrologue
        runner.run {
            switch interactable {
            case .fumi: isPrologue ? await prologue.talkToFumi() : await chapter1.talkToFumi()
            case .child: await prologue.talkToChild()
            case .taku: await chapter1.talkToTaku()
            case .takuBookmark: await chapter1.pickUpTakuBookmark()
            case .bookshelf(let index): await prologue.examineShelf(index)
            case .pictureBookShelf: await prologue.examinePictureBookShelf()
            case .bookmark: await prologue.pickUpBookmark()
            case .exit: isPrologue ? await prologue.exit() : await chapter1.exit()
            }
        }
    }

    private func interactInBook(with interactable: MelosInteractable) {
        let chapter1 = chapter1
        runner.run {
            switch interactable {
            case .river: await chapter1.river()
            case .bandits: await chapter1.bandits()
            case .collapse: await chapter1.collapse()
            case .rock(let index): await chapter1.examineRock(index)
            case .melosLying: await chapter1.talkToLyingMelos()
            case .philostratus: await chapter1.philostratus()
            case .gate: await chapter1.gate()
            }
        }
    }
}

/// 日没までの残り時間を、太陽と目盛りで見せる
private struct SunMeter: View {
    let clock: SunsetClock

    private static let segments = 10

    var body: some View {
        let filled = Int((clock.fraction * Double(Self.segments)).rounded(.up))
        let color: Color = clock.fraction > 0.5 ? Color(red: 1.0, green: 0.82, blue: 0.30)
            : clock.fraction > 0.2 ? Color(red: 1.0, green: 0.55, blue: 0.25)
            : Color(red: 0.95, green: 0.30, blue: 0.25)
        VStack(alignment: .trailing, spacing: 6) {
            Text("日没まで")
                .font(.pixel(12))
                .foregroundStyle(.white)
            HStack(spacing: 3) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                ForEach(0..<Self.segments, id: \.self) { index in
                    Rectangle()
                        .fill(index < filled ? color : Color(white: 0.3))
                        .frame(width: 7, height: 11)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RetroWindowBackground())
        .animation(.easeOut(duration: 0.3), value: filled)
    }
}

/// もちものの一覧
private struct ItemListView: View {
    let items: [StoryItem]
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 14) {
                Text("もちもの")
                    .font(.pixel(18))
                    .foregroundStyle(ShelfPalette.highlight)
                if items.isEmpty {
                    Text("なにも もっていないのだ")
                        .font(.pixel(15))
                        .foregroundStyle(.white)
                } else {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(item.imageName)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.pixel(16))
                                    .foregroundStyle(.white)
                                Text(item.detail)
                                    .font(.pixel(13))
                                    .foregroundStyle(Color(white: 0.8))
                            }
                        }
                    }
                }
                Button("とじる", action: close)
                    .font(.pixel(16))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .background(RetroWindowBackground())
            .padding(.horizontal, 24)
        }
    }
}
