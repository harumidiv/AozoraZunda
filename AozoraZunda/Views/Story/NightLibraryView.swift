import SwiftUI

/// 雨の夜だけ開く図書室。歩き回って幽霊と話し、ストーリーを進める。
/// 第1章からは、本の中（『走れメロス』『吾輩は猫である』『銀河鉄道の夜』の世界）にも入る
struct NightLibraryView: View {
    let story: StoryStore
    /// ずんだもんの部屋へ帰る
    let leave: () -> Void

    @State private var scene: NightLibraryScene
    @State private var runner: StoryRunner
    @State private var showsItems = false
    /// 開いている本の中のマップ（本の中にいないときは nil）
    @State private var melosScene: MelosScene?
    @State private var nekoScene: NekoScene?
    @State private var gingaScene: GingaScene?

    private enum Chapter {
        case prologue, chapter1, chapter2, chapter3
    }

    init(story: StoryStore, leave: @escaping () -> Void) {
        self.story = story
        self.leave = leave
        _scene = State(initialValue: NightLibraryScene(flags: story.flags))
        let runner = StoryRunner()
        // 章のはじめは、真っ暗な画面の語りや見出しから始める
        let startsChapter = !story.has(.prologueMetFumi)
            || (story.has(.prologueCleared) && !story.has(.chapter1Started))
            || (story.has(.chapter1Cleared) && !story.has(.chapter2Started))
            || (story.has(.chapter2Cleared) && !story.has(.chapter3Started))
        runner.setBlackedOut(startsChapter)
        _runner = State(initialValue: runner)
    }

    /// いま遊んでいる章（最後の章を終えたあとも、その章のまま）
    private var chapter: Chapter {
        if !story.has(.prologueCleared) {
            .prologue
        } else if !story.has(.chapter1Cleared) {
            .chapter1
        } else if !story.has(.chapter2Cleared) {
            .chapter2
        } else {
            .chapter3
        }
    }

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

    private var chapter2: Chapter2Events {
        let story = story
        return Chapter2Events(
            runner: runner,
            story: story,
            library: scene,
            openBook: { [self] in
                let book = NekoScene(flags: story.flags)
                nekoScene = book
                return book
            },
            closeBook: { [self] in nekoScene = nil },
            book: { [self] in nekoScene },
            leave: leave
        )
    }

    private var chapter3: Chapter3Events {
        let story = story
        return Chapter3Events(
            runner: runner,
            story: story,
            library: scene,
            openBook: { [self] in
                let book = GingaScene(flags: story.flags)
                gingaScene = book
                return book
            },
            closeBook: { [self] in gingaScene = nil },
            book: { [self] in gingaScene },
            leave: leave
        )
    }

    private var isInputEnabled: Bool { !runner.isRunning && !showsItems }

    private var libraryObjective: String {
        switch chapter {
        case .prologue: PrologueEvents.objective(story)
        case .chapter1: Chapter1Events.objective(story)
        case .chapter2: Chapter2Events.objective(story)
        case .chapter3: Chapter3Events.objective(story)
        }
    }

    var body: some View {
        Group {
            if let melosScene {
                WalkGameView(
                    scene: melosScene,
                    idleMessage: Chapter1Events.bookObjective(story, clock: melosScene.clock),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInMelos(with: interactable)
                }
                .overlay(alignment: .topTrailing) {
                    SunMeter(clock: melosScene.clock)
                        .padding(.top, 64)
                        .padding(.trailing, 16)
                        .allowsHitTesting(false)
                }
            } else if let nekoScene {
                WalkGameView(
                    scene: nekoScene,
                    idleMessage: Chapter2Events.bookObjective(nekoScene.progress),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInNeko(with: interactable)
                }
                .overlay(alignment: .topTrailing) {
                    NoteMeter(progress: nekoScene.progress)
                        .padding(.top, 64)
                        .padding(.trailing, 16)
                        .allowsHitTesting(false)
                }
            } else if let gingaScene {
                WalkGameView(
                    scene: gingaScene,
                    idleMessage: Chapter3Events.bookObjective(story, isCarrying: gingaScene.isCarryingLetter),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInGinga(with: interactable)
                }
            } else {
                WalkGameView(
                    scene: scene,
                    idleMessage: libraryObjective,
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
            switch chapter {
            case .prologue:
                let prologue = prologue
                runner.run { await prologue.arrive() }
            case .chapter1:
                let chapter1 = chapter1
                runner.run { await chapter1.arrive() }
            case .chapter2:
                let chapter2 = chapter2
                runner.run { await chapter2.arrive() }
            case .chapter3:
                let chapter3 = chapter3
                runner.run { await chapter3.arrive() }
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
        let chapter2 = chapter2
        let chapter3 = chapter3
        let chapter = chapter
        runner.run {
            switch interactable {
            case .fumi:
                switch chapter {
                case .prologue: await prologue.talkToFumi()
                case .chapter1: await chapter1.talkToFumi()
                case .chapter2: await chapter2.talkToFumi()
                case .chapter3: await chapter3.talkToFumi()
                }
            case .child: await prologue.talkToChild()
            case .taku: await chapter1.talkToTaku()
            case .takuBookmark: await chapter1.pickUpTakuBookmark()
            case .tama: await chapter2.talkToTama()
            case .sachi: await chapter3.talkToSachi()
            case .bookshelf(let index): await prologue.examineShelf(index)
            case .pictureBookShelf: await prologue.examinePictureBookShelf()
            case .bookmark: await prologue.pickUpBookmark()
            case .exit:
                switch chapter {
                case .prologue: await prologue.exit()
                case .chapter1: await chapter1.exit()
                case .chapter2: await chapter2.exit()
                case .chapter3: await chapter3.exit()
                }
            }
        }
    }

    private func interactInMelos(with interactable: MelosInteractable) {
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

    private func interactInNeko(with interactable: NekoInteractable) {
        let chapter2 = chapter2
        runner.run {
            switch interactable {
            case .hedgeNote: await chapter2.hedgeNote()
            case .master: await chapter2.master()
            case .zouni: await chapter2.zouni()
            case .mikeko: await chapter2.mikeko()
            case .brazier: await chapter2.brazier()
            case .kamado: await chapter2.kamado()
            case .table: await chapter2.table()
            }
        }
    }

    private func interactInGinga(with interactable: GingaInteractable) {
        let chapter3 = chapter3
        runner.run {
            switch interactable {
            case .seat(let index): await chapter3.seat(index)
            case .door(let index): await chapter3.door(index)
            case .doorway(let index): await chapter3.doorway(index)
            case .giovanni: await chapter3.giovanni()
            case .campanella: await chapter3.campanella()
            case .conductor: await chapter3.conductor()
            case .birdCatcher: await chapter3.birdCatcher()
            case .lighthouseKeeper: await chapter3.lighthouseKeeper()
            case .author: await chapter3.author()
            }
        }
    }
}

/// 拾ったキヨさんの書き込みの数
private struct NoteMeter: View {
    let progress: NoteProgress

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("キヨさんの書き込み")
                .font(.pixel(12))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(0..<NoteProgress.total, id: \.self) { index in
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(index < progress.count ? Color(red: 0.95, green: 0.76, blue: 0.31) : Color(white: 0.35))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RetroWindowBackground())
        .animation(.easeOut(duration: 0.3), value: progress.count)
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
