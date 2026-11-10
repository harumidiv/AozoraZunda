import SwiftUI

/// 幽霊図鑑。成仏を手伝った幽霊と、その本。
/// エピローグのあとは、ずんだもんがぜんぶ読み直して書いた「読書感想メモ」が加わる
struct GhostBookView: View {
    let story: StoryStore
    let close: () -> Void

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let image: String
        let book: String
        let note: String
        let memo: String
        let unlocked: StoryFlag
    }

    private var entries: [Entry] {
        let catMemo = story.memos[Chapter2Events.memoKey].map { "「\($0)」って、すみっこに書いたのだ。" } ?? ""
        let card = story.memos[Chapter3Events.memoKey] ?? ""
        return [
            Entry(id: "child", name: "まいごの子", image: "sprite_child_happy_0", book: "『ほしのこ ポロン』",
                  note: "あおい絵本を読んでほしかった、ちいさな子",
                  memo: "絵本は本じゃないって言ったけど……ちょっとだけ、本だったのだ。ポロン、おうちに帰れてよかったのだ。",
                  unlocked: .prologueChildPassed),
            Entry(id: "taku", name: "タク", image: "sprite_taku_happy_0", book: "太宰治『走れメロス』",
                  note: "メロスが間に合ったか知りたかった中学生",
                  memo: "続きが気になって、ほんとうに眠れなかったのだ。メロスは、走って、走って、間に合ったのだ。",
                  unlocked: .chapter1Cleared),
            Entry(id: "tama", name: "タマ", image: "sprite_tama_0", book: "夏目漱石『吾輩は猫である』",
                  note: "キヨさんの読み聞かせが忘れられなかった猫",
                  memo: "吾輩は猫である。名前は、ちゃんとあったのだ。\(catMemo)",
                  unlocked: .chapter2Cleared),
            Entry(id: "sachi", name: "サチ", image: "sprite_sachi_happy_0", book: "宮沢賢治『銀河鉄道の夜』",
                  note: "作者に手紙を届けたかった女の子",
                  memo: "ほんとうのさいわいは、まだわからないのだ。でも、ジョバンニみたいに、さがしてみるのだ。",
                  unlocked: .chapter3Cleared),
            Entry(id: "brothers", name: "タイチとジロ", image: "sprite_brother_elder_0", book: "宮沢賢治『注文の多い料理店』",
                  note: "もう一度、二人で読み合わせをしたかった兄弟",
                  memo: "声に出して読むと、笑い声まで一緒に覚えていられるのだ。「わん、わん、ぐゎあ」は忘れてほしいのだ。",
                  unlocked: .chapter4Cleared),
            Entry(id: "haru", name: "はる", image: "sprite_haru_happy_0", book: "新美南吉『手袋を買いに』",
                  note: "本を返す約束を、ずっと守りたかった女の子",
                  memo: "ほんとうに人間はいいものかしら。……いいものだったのだ。最後まで読んで、よかったのだ。",
                  unlocked: .finaleFumiPassed),
            Entry(id: "fumi", name: "おフミさん", image: "sprite_fumi_0", book: "夜だけ開く図書室",
                  note: "前の司書さん。ずんだ餅が好き",
                  memo: card.isEmpty ? "ずんだ餅、こんどおそなえするのだ。" : card,
                  unlocked: .finaleFumiPassed),
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 12) {
                Text("幽霊図鑑")
                    .font(.pixel(18))
                    .foregroundStyle(ShelfPalette.highlight)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                }
                .frame(maxHeight: 460)
                if !story.has(.epilogueCleared) {
                    Text("……最後まで読むと、何か書き足されるかもしれないのだ")
                        .font(.pixel(12))
                        .foregroundStyle(Color(white: 0.7))
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

    @ViewBuilder
    private func row(_ entry: Entry) -> some View {
        let isUnlocked = story.has(entry.unlocked)
        HStack(alignment: .top, spacing: 12) {
            Image(entry.image)
                .interpolation(.none)
                .resizable()
                .frame(width: 40, height: 40)
                .opacity(isUnlocked ? 1 : 0)
                .background(isUnlocked ? Color.clear : Color(white: 0.2))
            VStack(alignment: .leading, spacing: 4) {
                Text(isUnlocked ? entry.name : "？？？")
                    .font(.pixel(16))
                    .foregroundStyle(.white)
                if isUnlocked {
                    Text(entry.book)
                        .font(.pixel(13))
                        .foregroundStyle(Color(white: 0.85))
                    Text(entry.note)
                        .font(.pixel(12))
                        .foregroundStyle(Color(white: 0.7))
                    if story.has(.epilogueCleared) {
                        Text("ずんだもんの読書感想メモ")
                            .font(.pixel(12))
                            .foregroundStyle(Color(red: 0.62, green: 0.88, blue: 0.45))
                            .padding(.top, 4)
                        Text(entry.memo)
                            .font(.pixel(13))
                            .foregroundStyle(Color(red: 0.24, green: 0.15, blue: 0.10))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.97, green: 0.93, blue: 0.82))
                    }
                }
            }
        }
    }
}
