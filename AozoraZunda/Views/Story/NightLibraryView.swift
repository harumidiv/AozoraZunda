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
    /// 歩き回る幽霊に話しかけた回数（話しかけるたびに次のセリフにする）
    @State private var wandererTalks: [NightWanderer: Int] = [:]
    /// 開いている本の中のマップ（本の中にいないときは nil）
    @State private var melosScene: MelosScene?
    @State private var nekoScene: NekoScene?
    @State private var gingaScene: GingaScene?
    @State private var yamanekoScene: YamanekoScene?
    @State private var tebukuroScene: TebukuroScene?
    @State private var showsGhostBook = false

    enum Chapter {
        case prologue, chapter1, chapter2, chapter3, chapter4, chapter5, finale
    }

    init(story: StoryStore, leave: @escaping () -> Void) {
        self.story = story
        self.leave = leave
        let scene = NightLibraryScene(flags: story.flags)
        scene.isStoryTarget = { [story] in Self.isStoryTarget($0, story: story) }
        _scene = State(initialValue: scene)
        let runner = StoryRunner()
        // 章のはじめは、真っ暗な画面の語りや見出しから始める
        let startsChapter = !story.has(.prologueMetFumi)
            || (story.has(.prologueCleared) && !story.has(.chapter1Started))
            || (story.has(.chapter1Cleared) && !story.has(.chapter2Started))
            || (story.has(.chapter2Cleared) && !story.has(.chapter3Started))
            || (story.has(.chapter3Cleared) && !story.has(.chapter4Started))
            || (story.has(.chapter4Cleared) && !story.has(.chapter5Started))
            || (story.has(.chapter5Cleared) && !story.has(.finaleStarted))
            || (story.has(.finaleCleared) && !story.has(.epilogueCleared))
        runner.setBlackedOut(startsChapter)
        _runner = State(initialValue: runner)
    }

    /// いま遊んでいる章（最後の章を終えたあとも、その章のまま）
    private var chapter: Chapter { Self.chapter(story) }

    static func chapter(_ story: StoryStore) -> Chapter {
        if !story.has(.prologueCleared) {
            .prologue
        } else if !story.has(.chapter1Cleared) {
            .chapter1
        } else if !story.has(.chapter2Cleared) {
            .chapter2
        } else if !story.has(.chapter3Cleared) {
            .chapter3
        } else if !story.has(.chapter4Cleared) {
            .chapter4
        } else if !story.has(.chapter5Cleared) {
            .chapter5
        } else {
            .finale
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
                book.isStoryTarget = { [weak book] in
                    guard let book else { return false }
                    return Chapter1Events.isStoryTarget($0, story: story, clock: book.clock)
                }
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
                book.isStoryTarget = { [weak book] in
                    guard let book else { return false }
                    return Chapter2Events.isStoryTarget($0, story: story, progress: book.progress)
                }
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
                book.isStoryTarget = { [weak book] in
                    guard let book else { return false }
                    return Chapter3Events.isStoryTarget($0, story: story, scene: book)
                }
                book.isAvailable = { [weak book] in
                    guard let book else { return false }
                    return Chapter3Events.isAvailable($0, story: story, scene: book)
                }
                gingaScene = book
                return book
            },
            closeBook: { [self] in gingaScene = nil },
            book: { [self] in gingaScene },
            leave: leave
        )
    }

    private var chapter4: Chapter4Events {
        Chapter4Events(
            runner: runner,
            story: story,
            library: scene,
            openBook: { [self] in
                let book = YamanekoScene()
                book.isStoryTarget = { [weak book] in
                    guard let book else { return false }
                    return Chapter4Events.isStoryTarget($0, scene: book)
                }
                book.isAvailable = { [weak book, story] in
                    guard let book else { return false }
                    return Chapter4Events.isAvailable($0, story: story, scene: book)
                }
                yamanekoScene = book
                return book
            },
            closeBook: { [self] in yamanekoScene = nil },
            book: { [self] in yamanekoScene },
            leave: leave
        )
    }

    private var chapter5: Chapter5Events {
        Chapter5Events(runner: runner, story: story, library: scene, leave: leave)
    }

    private var finale: FinaleEvents {
        let story = story
        return FinaleEvents(
            runner: runner,
            story: story,
            library: scene,
            openBook: { [self] in
                let book = TebukuroScene(flags: story.flags)
                book.isStoryTarget = { FinaleEvents.isStoryTarget($0, story: story) }
                tebukuroScene = book
                return book
            },
            closeBook: { [self] in tebukuroScene = nil },
            book: { [self] in tebukuroScene },
            leave: leave
        )
    }

    /// いま流す曲。開いている本の曲、本の外なら図書室の曲。物語の大事な場面では、そちらを優先する
    private var music: StoryMusic {
        if let music = runner.music {
            music
        } else if melosScene != nil {
            .melos
        } else if nekoScene != nil {
            .neko
        } else if gingaScene != nil {
            .ginga
        } else if yamanekoScene != nil {
            .yamaneko
        } else if tebukuroScene != nil {
            .tebukuro
        } else {
            .nightLibrary
        }
    }

    private var isInputEnabled: Bool { !runner.isRunning && !showsItems && !showsGhostBook }

    private var libraryObjective: String {
        switch chapter {
        case .prologue: PrologueEvents.objective(story)
        case .chapter1: Chapter1Events.objective(story)
        case .chapter2: Chapter2Events.objective(story)
        case .chapter3: Chapter3Events.objective(story)
        case .chapter4: Chapter4Events.objective(story)
        case .chapter5: Chapter5Events.objective(story)
        case .finale: FinaleEvents.objective(story)
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
            } else if let yamanekoScene {
                WalkGameView(
                    scene: yamanekoScene,
                    idleMessage: Chapter4Events.bookObjective(yamanekoScene),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInYamaneko(with: interactable)
                }
                .overlay(alignment: .topTrailing) {
                    ReadAlongMeter(progress: yamanekoScene.progress)
                        .padding(.top, 64)
                        .padding(.trailing, 16)
                        .allowsHitTesting(false)
                }
            } else if let tebukuroScene {
                WalkGameView(
                    scene: tebukuroScene,
                    idleMessage: FinaleEvents.bookObjective(story),
                    isInputEnabled: isInputEnabled
                ) { interactable in
                    interactInTebukuro(with: interactable)
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
                HStack(spacing: 10) {
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
                    if story.has(.prologueChildPassed) {
                        Button {
                            showsGhostBook = true
                        } label: {
                            Text("ずかん")
                                .font(.pixel(15))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(RetroWindowBackground())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 24)
                .padding(.bottom, 16)
            }
        }
        .overlay {
            if showsGhostBook {
                GhostBookView(story: story) { showsGhostBook = false }
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
            case .chapter4:
                let chapter4 = chapter4
                runner.run { await chapter4.arrive() }
            case .chapter5:
                let chapter5 = chapter5
                runner.run { await chapter5.arrive() }
            case .finale:
                let finale = finale
                runner.run { await finale.arrive() }
            }
        }
        .onChange(of: music, initial: true) { _, music in
            MusicPlayer.shared.play(music)
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
        let chapter4 = chapter4
        let chapter5 = chapter5
        let finale = finale
        let chapter = chapter
        if case .wanderer(let wanderer) = interactable {
            talk(to: wanderer)
            return
        }
        runner.run {
            switch interactable {
            case .fumi:
                switch chapter {
                case .prologue: await prologue.talkToFumi()
                case .chapter1: await chapter1.talkToFumi()
                case .chapter2: await chapter2.talkToFumi()
                case .chapter3: await chapter3.talkToFumi()
                case .chapter4: await chapter4.talkToFumi()
                case .chapter5: await chapter5.talkToFumi()
                case .finale: await finale.talkToFumi()
                }
            case .child: await prologue.talkToChild()
            case .taku: await chapter1.talkToTaku()
            case .takuBookmark: await chapter1.pickUpTakuBookmark()
            case .tama: await chapter2.talkToTama()
            case .sachi: await chapter3.talkToSachi()
            case .brothers: await chapter4.talkToBrothers()
            case .cardBox: await chapter5.cardBox()
            case .shadow: await chapter5.shadow()
            case .haru: await finale.talkToHaru()
            case .newcomer: await finale.talkToNewcomer()
            case .bookshelf(let index):
                switch chapter {
                case .chapter5 where index == NightLibraryInteractable.cornerShelf:
                    await chapter5.cornerShelf()
                case .finale where index == NightLibraryInteractable.cornerShelf:
                    await finale.cornerShelf()
                case .finale:
                    await finale.otherShelf()
                default:
                    await prologue.examineShelf(index)
                }
            case .pictureBookShelf: await prologue.examinePictureBookShelf()
            case .bookmark: await prologue.pickUpBookmark()
            case .wanderer: break
            case .exit:
                switch chapter {
                case .prologue: await prologue.exit()
                case .chapter1: await chapter1.exit()
                case .chapter2: await chapter2.exit()
                case .chapter3: await chapter3.exit()
                case .chapter4: await chapter4.exit()
                case .chapter5: await chapter5.exit()
                case .finale: await finale.exit()
                }
            }
        }
    }

    /// ストーリーに関係のない幽霊の、ひとことのうわさ話
    private func talk(to wanderer: NightWanderer) {
        let lines = wanderer.lines(story.flags)
        guard !lines.isEmpty else { return }
        let count = wandererTalks[wanderer, default: 0]
        wandererTalks[wanderer] = count + 1
        let line = lines[count % lines.count]
        runner.run { [runner] in
            await runner.say(.wanderer(wanderer), line)
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

extension NightLibraryView {
    private func interactInYamaneko(with interactable: YamanekoInteractable) {
        let chapter4 = chapter4
        runner.run {
            switch interactable {
            case .door(let index): await chapter4.door(index)
            case .doorway(let index): await chapter4.doorway(index)
            case .station(let station): await chapter4.station(station)
            case .signboard: await chapter4.signboard()
            }
        }
    }

    private func interactInTebukuro(with interactable: TebukuroInteractable) {
        let finale = finale
        runner.run {
            switch interactable {
            case .foxes: await finale.foxes()
            case .footprints(let index): await finale.footprints(index)
            case .glimpse: await finale.glimpse()
            case .sign(let index): await finale.sign(index)
            case .hatShop: await finale.hatShop()
            case .lullabyWindow: await finale.lullabyWindow()
            case .haru: await finale.haruInBook()
            }
        }
    }
}

/// 兄弟の読み合わせの進み具合（ジロの姿がはっきりしていく）
private struct ReadAlongMeter: View {
    let progress: ReadAlongProgress

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("読み合わせ")
                .font(.pixel(12))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(0..<ReadAlongProgress.total, id: \.self) { index in
                    Image(systemName: "music.note")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(index < progress.count ? Color(red: 0.62, green: 0.78, blue: 1.0) : Color(white: 0.35))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RetroWindowBackground())
        .animation(.easeOut(duration: 0.3), value: progress.count)
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
