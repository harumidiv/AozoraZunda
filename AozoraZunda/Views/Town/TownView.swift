import SwiftUI

/// ずんだもんの家と図書館のあいだの町。町の人から「こんな本が読みたい」と頼まれ、
/// 図書館で借りた本を届ける
struct TownView: View {
    @Environment(ErrandStore.self) private var errands
    @Environment(StoryStore.self) private var story
    /// ずんだもんの部屋に帰る
    let goHome: () -> Void
    /// 図書館に入る
    let goToLibrary: () -> Void

    @State private var scene: TownScene
    @State private var runner = StoryRunner()
    @State private var showsErrands = false

    init(entrance: TownScene.Entrance, goHome: @escaping () -> Void, goToLibrary: @escaping () -> Void) {
        self.goHome = goHome
        self.goToLibrary = goToLibrary
        _scene = State(initialValue: TownScene(entrance: entrance))
    }

    private var isInputEnabled: Bool { !runner.isRunning && !showsErrands }

    private var idleMessage: String {
        // 夜の図書室で頼まれたことがあれば、そちらを先に案内する
        if let task = StoryDayTask.current(story) {
            return task.townObjective
        } else if let task = StoryDayTask.ready(story) {
            return task.readyObjective
        }
        if let book = errands.carrying {
            return "『\(book.title)』をかりているのだ。待っている人に届けるのだ"
        } else if errands.isLookingForBook {
            return "たのまれた本を、上の図書館でさがしてかりるのだ"
        }
        return "町なのだ。読みたい本をさがしている人がいるかもしれないのだ。「！」の人に話しかけるのだ"
    }

    /// 話しかけると何かある人（新しい頼みごとがある・借りた本がぴったり）
    private var wishingPeople: Set<Townsperson> {
        Set(Townsperson.allCases.filter { person in
            guard let wish = errands.currentWish(of: person) else { return false }
            if !errands.isAccepted(wish) { return true }
            return errands.carrying.map(wish.matches) ?? false
        })
    }

    var body: some View {
        WalkGameView(
            scene: scene,
            idleMessage: idleMessage,
            isInputEnabled: isInputEnabled
        ) { interactable in
            interact(with: interactable)
        }
        .overlay(alignment: .bottomLeading) {
            if isInputEnabled {
                Button {
                    showsErrands = true
                } label: {
                    Text("たのまれごと")
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
            if showsErrands {
                ErrandListView(errands: errands) { showsErrands = false }
            }
        }
        .overlay {
            StoryOverlay(runner: runner)
        }
        .onAppear(perform: refreshScene)
        .onChange(of: errands.carrying) { refreshScene() }
        .onChange(of: errands.accepted) { refreshScene() }
        .onChange(of: errands.delivered) { refreshScene() }
        .onChange(of: story.flags) { refreshScene() }
    }

    /// 朝のおつかいで話しかける相手
    private var storyPerson: Townsperson? {
        StoryDayTask.current(story)?.person
    }

    private func refreshScene() {
        scene.showCarriedBook(errands.carrying != nil)
        scene.updateMarks(wishing: wishingPeople, story: storyPerson)
        scene.isStoryTarget = { [story] interactable in
            guard let task = StoryDayTask.current(story) else { return false }
            if let person = task.person {
                return interactable == .person(person)
            }
            // 本を借りるおつかいは、図書館の入口へ
            return interactable == .library
        }
    }

    private func interact(with interactable: TownInteractable) {
        switch interactable {
        case .home:
            goHome()
        case .library:
            goToLibrary()
        case .signpost:
            runner.run { [runner] in
                await runner.say(.zunda, "「↑ としょかん　← ずんだもんの家　→ パン屋・公園」って書いてあるのだ")
            }
        case .person(let person):
            let events = TownEvents(runner: runner, errands: errands, scene: scene)
            let dayEvents = StoryDayEvents(runner: runner, story: story)
            runner.run {
                if await dayEvents.talk(to: person) { return }
                await dayEvents.hint(from: person)
                await events.talk(to: person)
            }
        }
    }
}

/// 町の人との会話
private struct TownEvents {
    let runner: StoryRunner
    let errands: ErrandStore
    let scene: TownScene

    func talk(to person: Townsperson) async {
        let speaker = StorySpeaker.townsperson(person)
        guard let wish = errands.currentWish(of: person) else {
            await runner.say(speaker, person.allDoneLine)
            return
        }

        if !errands.isAccepted(wish) {
            await ask(wish, speaker: speaker)
        } else if let book = errands.carrying {
            await offer(book, for: wish, speaker: speaker)
        } else {
            let choice = await runner.choose(speaker, "\(wish.summary)……見つかりそう？", ["ヒントがほしいのだ", "さがしにいくのだ"])
            if choice == 0 {
                await runner.say(.zunda, wish.hint)
            } else {
                await runner.say(speaker, "ありがとう。たのしみに待ってるね")
            }
        }
    }

    /// 「こんな本が読みたい」と頼まれる
    private func ask(_ wish: BookWish, speaker: StorySpeaker) async {
        for line in wish.request.dropLast() {
            await runner.say(speaker, line)
        }
        let choice = await runner.choose(speaker, wish.request.last ?? "", ["まかせるのだ！", "またこんどなのだ"])
        if choice == 0 {
            errands.accept(wish)
            await runner.say(.zunda, "ずんだもんが図書館でさがしてくるのだ！")
            await runner.say(speaker, "ほんと？ たすかる！")
        } else {
            await runner.say(speaker, "そっか。気が向いたら、また声をかけてね")
        }
    }

    /// 借りてきた本を渡す
    private func offer(_ book: CatalogBook, for wish: BookWish, speaker: StorySpeaker) async {
        let choice = await runner.choose(.zunda, "『\(book.title)』をかりてきたのだ。これはどうなのだ？", ["わたす", "ヒントがほしいのだ", "やめておく"])
        switch choice {
        case 0:
            guard wish.matches(book) else {
                await runner.say(speaker, wish.wrongBook)
                await runner.say(.zunda, "むむ……。\(wish.hint)")
                return
            }
            for line in wish.thanks {
                await runner.say(speaker, line)
            }
            errands.deliver(wish)
            await scene.cheer(wish.person)
            await runner.say(.zunda, "おとどけ完了なのだ！（これで\(errands.deliveredCount)冊目なのだ）")
            if errands.currentWish(of: wish.person) != nil {
                await runner.say(speaker, "……また、本のことで相談してもいい？ 読み終わったら、声をかけるね")
            }
        case 1:
            await runner.say(.zunda, wish.hint)
        default:
            break
        }
    }
}

/// 引き受けた頼まれごとと、かりている本の一覧
private struct ErrandListView: View {
    let errands: ErrandStore
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 14) {
                Text("たのまれごと")
                    .font(.pixel(18))
                    .foregroundStyle(ShelfPalette.highlight)
                let pending = errands.pendingWishes
                if pending.isEmpty {
                    Text("いまは なにも たのまれていないのだ。「！」の人に話しかけるのだ")
                        .font(.pixel(15))
                        .foregroundStyle(.white)
                } else {
                    ForEach(pending) { wish in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wish.person.name)
                                .font(.pixel(13))
                                .foregroundStyle(StorySpeaker.townsperson(wish.person).color)
                            Text(wish.summary)
                                .font(.pixel(15))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.4))

                if let book = errands.carrying {
                    HStack(alignment: .center, spacing: 12) {
                        Image("sprite_town_carried_book")
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 27, height: 21)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("かりている本")
                                .font(.pixel(13))
                                .foregroundStyle(Color(white: 0.8))
                            Text("\(book.authorName)『\(book.title)』")
                                .font(.pixel(15))
                                .foregroundStyle(.white)
                        }
                        Spacer(minLength: 0)
                        Button("かえす") { errands.returnBook() }
                            .font(.pixel(14))
                            .foregroundStyle(ShelfPalette.highlight)
                            .buttonStyle(.plain)
                    }
                } else {
                    Text("かりている本はないのだ")
                        .font(.pixel(14))
                        .foregroundStyle(Color(white: 0.8))
                }
                Text("届けた本: \(errands.deliveredCount) / \(BookWish.all.count)冊")
                    .font(.pixel(14))
                    .foregroundStyle(Color(white: 0.8))

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
