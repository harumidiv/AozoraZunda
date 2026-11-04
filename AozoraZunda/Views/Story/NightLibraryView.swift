import SwiftUI

/// 雨の夜だけ開く図書室。歩き回って幽霊と話し、ストーリーを進める
struct NightLibraryView: View {
    let story: StoryStore
    /// ずんだもんの部屋へ帰る
    let leave: () -> Void

    @State private var scene: NightLibraryScene
    @State private var runner: StoryRunner
    @State private var showsItems = false

    init(story: StoryStore, leave: @escaping () -> Void) {
        self.story = story
        self.leave = leave
        _scene = State(initialValue: NightLibraryScene(flags: story.flags))
        let runner = StoryRunner()
        // はじめて来たときは、真っ暗な画面の語りから始める
        runner.setBlackedOut(!story.has(.prologueMetFumi))
        _runner = State(initialValue: runner)
    }

    private var events: PrologueEvents {
        PrologueEvents(runner: runner, story: story, scene: scene, leave: leave)
    }

    var body: some View {
        WalkGameView(
            scene: scene,
            idleMessage: PrologueEvents.objective(story),
            isInputEnabled: !runner.isRunning && !showsItems
        ) { interactable in
            interact(with: interactable)
        }
        .overlay(alignment: .bottomLeading) {
            if !runner.isRunning && !showsItems {
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
            let events = events
            runner.run { await events.arrive() }
        }
    }

    private func interact(with interactable: NightLibraryInteractable) {
        let events = events
        runner.run {
            switch interactable {
            case .fumi: await events.talkToFumi()
            case .child: await events.talkToChild()
            case .bookshelf(let index): await events.examineShelf(index)
            case .pictureBookShelf: await events.examinePictureBookShelf()
            case .bookmark: await events.pickUpBookmark()
            case .exit: await events.exit()
            }
        }
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
