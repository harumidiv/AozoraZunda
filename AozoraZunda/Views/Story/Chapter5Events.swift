import Foundation

/// 第5章「消えた本」のイベント。お客さんの来ない夜、ずんだもんは
/// すみの棚の一冊ぶんの隙間と、何十年も「貸出中」のままの貸出カードに気づく。
/// 本の中には入らない、図書室だけの短い章
struct Chapter5Events {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 部屋に帰る
    let leave: () -> Void

    /// 貸出カード
    static let card: [HandwrittenNote] = [
        HandwrittenNote(text: "書名　手袋を買いに\n著者　新美南吉"),
        HandwrittenNote(text: "貸出日　二月三日\n返却日　"),
        HandwrittenNote(text: "なまえ　はる", isOtherHand: true),
    ]

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.chapter5SawShadow) {
            return "おフミさんに、話しかけるのだ"
        } else if story.has(.chapter5AskedFumi) {
            return "すみの棚のほうで、何かが動いたのだ"
        } else if story.has(.chapter5ReadCard) {
            return "おフミさんに、カードのことを聞いてみるのだ"
        } else if story.has(.chapter5FoundGap) {
            return "カウンターの、貸出カードの箱を調べてみるのだ"
        } else if story.has(.chapter5Started) {
            return "今夜はお客さんがいないのだ。……しおりを挟んだ、すみの棚を見てみるのだ"
        }
        return "夜の図書室なのだ"
    }

    // MARK: - 図書室

    func arrive() async {
        if !story.has(.chapter5Started) {
            await opening()
        } else if !story.has(.chapter5Cleared) {
            await runner.say(.fumi, "あら、いらっしゃい。……今夜も、お客さんはいないわ")
        }
    }

    private func opening() async {
        await runner.chapterTitle("第5章", "消えた本")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.zunda, "……今夜は、閲覧机に誰もいないのだ")
        await runner.say(.fumi, "そういう夜もあるわ。お客さんがいない夜は、司書はお片づけと、本の手入れ")
        await runner.say(.zunda, "……じゃあ、ずんだもんは……ちょっと、本でも見てみるのだ")
        await runner.say(.fumi, "…………え？")
        await runner.say(.zunda, "な、なんなのだ。ひまだから見るだけなのだ。読むとは言ってないのだ")
        await runner.say(.zunda, "（そういえば……最初の夜に、すみの棚にしおりを挟んだのだ）")
        story.set(.chapter5Started)
    }

    func talkToFumi() async {
        if story.has(.chapter5SawShadow) {
            await wantToRead()
        } else if story.has(.chapter5AskedFumi) {
            await runner.say(.fumi, "…………")
            await runner.say(.zunda, "（おフミさん、ずっと、すみの棚のほうを見てるのだ）")
        } else if story.has(.chapter5ReadCard) {
            await askAboutCard()
        } else {
            await runner.say(.fumi, "本の手入れ、手伝ってくれるの？ ……今夜のずんだもんちゃん、なんだか司書さんみたい")
        }
    }

    /// すみの棚（しおりを挟んだ棚）
    func cornerShelf() async {
        if story.has(.chapter5FoundGap) {
            await runner.say(.zunda, "一冊ぶんの隙間なのだ。……『手袋を買いに』が、ここに入るはずなのだ")
            return
        }
        await runner.say(.zunda, "最初の夜に、しおりを挟んだ棚なのだ。赤いひもが、まだのぞいてるのだ")
        await runner.say(.zunda, "……あれ？ しおりを挟んだところ、本と本の間じゃないのだ")
        await runner.say(.zunda, "一冊ぶん、ぽっかり空いてるのだ。……しおりだけが、本のかわりにはさまってたのだ")
        library.removeShelvedBookmark()
        story.give(.bookmark)
        await runner.showItemGet(.bookmark)
        await runner.say(.zunda, "隙間の奥に、小さな札が貼ってあるのだ")
        await runner.quote("新美南吉『手袋を買いに』")
        await runner.say(.zunda, "ここにあるはずの本なのだ。……誰かが借りたまま、なのだ？")
        story.set(.chapter5FoundGap)
    }

    func cardBox() async {
        guard story.has(.chapter5FoundGap) else {
            await runner.say(.zunda, "貸出カードの箱なのだ。古いカードがぎっしりなのだ。……字がいっぱいで、眠くなりそうなのだ")
            return
        }
        if story.has(.chapter5ReadCard) {
            await runner.showHandwriting(Self.card)
            await runner.say(.zunda, "返却日の欄が、空っぽのままなのだ")
            return
        }
        await runner.say(.zunda, "『手袋を買いに』のカード……カード……。あったのだ！")
        await runner.showHandwriting(Self.card)
        await runner.say(.zunda, "返却日の欄が、空っぽなのだ。貸出の日付は……すごく、すごく昔なのだ")
        await runner.say(.zunda, "最後の名前は……「はる」。子どもの、まるい字なのだ")
        await runner.say(.zunda, "（「さっちゃん」でも、「キヨちゃん」でもない……知らない名前なのだ）")
        story.give(.lendingCard)
        story.set(.chapter5ReadCard)
        await runner.showItemGet(.lendingCard)
    }

    private func askAboutCard() async {
        await runner.say(.zunda, "おフミさん。すみの棚の『手袋を買いに』、何十年も貸出中のままなのだ")
        await runner.say(.zunda, "借りたのは「はる」っていう子なのだ。おフミさん、知ってるのだ？")
        await runner.say(.fumi, "……………………")
        await runner.say(.fumi, "……さあね")
        await runner.say(.zunda, "（おフミさんが、笑ってないのだ。……はじめて見たのだ）")
        await runner.say(.fumi, "……古いカードは、いろいろあるのよ。気にしなくていいわ")
        story.set(.chapter5AskedFumi)
        library.showShadow()
        await runner.say(.zunda, "…………！ い、今、すみの棚のほうで、何か動いたのだ")
    }

    func shadow() async {
        await runner.say(.zunda, "本を……かかえた、小さな影なのだ")
        await library.vanishShadow()
        story.set(.chapter5SawShadow)
        await runner.say(.unknown, "……かえさなきゃ……")
        await runner.say(.zunda, "消えちゃったのだ。……青い表紙の本、かかえてたのだ")
        await runner.say(.zunda, "（三つ編みの、女の子だったのだ。……おフミさんに、ちゃんと聞くのだ）")
    }

    /// ずんだもんが、はじめて自分から「読みたい」と言う
    private func wantToRead() async {
        await runner.say(.zunda, "おフミさん。今、すみの棚に、本をかかえた女の子がいたのだ")
        await runner.say(.fumi, "…………そう")
        await runner.say(.zunda, "「かえさなきゃ」って、言ってたのだ")
        await runner.say(.fumi, "……………………")
        await runner.say(.zunda, "おフミさんが話したくないなら、聞かないのだ。でも……")
        await runner.say(.zunda, "でも、ずんだもん、思ったのだ")
        await runner.blackOut(true, duration: 0.8)
        await runner.narrate("この本、ずんだもんが読みたいのだ。")
        await runner.blackOut(false, duration: 0.8)
        await runner.say(.fumi, "……ずんだもんちゃん、今、なんて？")
        await runner.say(.zunda, "『手袋を買いに』。ずんだもんが、読みたいのだ。……字を見ると眠くなるけど、それでも読みたいのだ")
        await runner.say(.zunda, "誰かに頼まれたからじゃないのだ。ずんだもんが、読みたいのだ")
        await runner.say(.fumi, "…………")
        await runner.say(.fumi, "……あの本はね、まだ、返ってきてないの")
        await runner.say(.fumi, "ずっと、ずっと、待ってるの。……わたしの願いは、まだいいの、って言ってたでしょう")
        await runner.say(.fumi, "……ごめんね。つぎの雨の夜に、ちゃんと話すわ")
        story.set(.chapter5Cleared)
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは、\nもらった押し花のしおりを、\nずっと手の中で転がしていたのだ。")
        await runner.chapterTitle("第5章 おわり", "消えた本")
        await runner.narrate("つぎのお話「最後まで読むのだ」は、\nまた夜になったら始まるのだ。")
        leave()
    }

    func exit() async {
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "おやすみなさい。……気をつけてね")
        await runner.blackOut(true)
        leave()
    }
}
