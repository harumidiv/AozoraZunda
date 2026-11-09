import Foundation

/// 第3章「手紙は届くのだ」のイベント。
/// 大好きな作者へのファンレターを出せないままだった少女の幽霊・サチと、
/// 『銀河鉄道の夜』の汽車に乗って、終点の停車場まで手紙を届けに行く。
/// 本の中の一節は青空文庫の『銀河鉄道の夜』（宮沢賢治）から引用している
struct Chapter3Events {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 本の中へ入る。作った本の中のマップを返す
    let openBook: () -> GingaScene
    /// 本を閉じて図書室に戻る
    let closeBook: () -> Void
    let book: () -> GingaScene?
    /// 部屋に帰る
    let leave: () -> Void

    static let source = "『銀河鉄道の夜』宮沢賢治"
    static let memoKey = "おフミさんへのカード"

    /// サチの手紙
    static let letter: [HandwrittenNote] = [
        HandwrittenNote(text: "作者さまへ。\n『銀河鉄道の夜』を、なんども読みました。"),
        HandwrittenNote(text: "カムパネルラがいなくなるところで、\nいつも泣いてしまいます。"),
        HandwrittenNote(text: "わたしも、ジョバンニみたいに、\nほんとうのさいわいを、さがしてみます。"),
        HandwrittenNote(text: "いつか、つづきが読めたらうれしいです。\n　　　　　　　　　　　　サチ"),
    ]

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.chapter3Cleared) {
            return "夜の図書室なのだ"
        } else if story.has(.chapter3LetterDelivered) {
            return "サチに声をかけるのだ"
        } else if story.has(.unsentLetter) {
            return "サチと一緒に、本の中の汽車で手紙を届けに行くのだ"
        } else if story.has(.chapter3Started) {
            return "閲覧机の女の子に話しかけるのだ"
        }
        return "夜の図書室なのだ"
    }

    /// 本の中にいるときの「いまやること」
    static func bookObjective(_ story: StoryStore, isCarrying: Bool) -> String {
        if !isCarrying {
            return "手紙を座席に置いているのだ。忘れずに拾うのだ"
        } else if story.has(.chapter3AppleTaken) {
            return "前の扉の向こうが、終点の停車場なのだ"
        } else if story.has(.chapter3CandyEaten) {
            return "三両目なのだ。乗客に話しかけてみるのだ"
        } else if story.has(.chapter3TicketShown) {
            return "二両目なのだ。乗客に話しかけてみるのだ"
        }
        return "手紙を両手でかかえて、汽車の終点をめざすのだ"
    }

    // MARK: - 図書室

    func arrive() async {
        if !story.has(.chapter3Started) {
            await opening()
        } else if !story.has(.chapter3Cleared) {
            await runner.say(.fumi, "おかえりなさい。サチちゃんが待ってるわよ")
        }
    }

    private func opening() async {
        await runner.chapterTitle("第3章", "手紙は届くのだ")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.fumi, "いらっしゃい。今夜のお客さんは、ほら、閲覧机のところ")
        await runner.say(.zunda, "セーラー服の女の子なのだ。……封筒を、ぎゅっとかかえてるのだ")
        story.set(.chapter3Started)
    }

    func talkToFumi() async {
        if story.has(.chapter3Cleared) {
            await runner.say(.fumi, "今夜は静かね。……つぎのお客さんは、まだみたい")
            await runner.say(.zunda, "べ、別におフミさんに会いに来たわけじゃないのだ")
            let choice = await runner.choose(.fumi, "ふふ。ゆっくりしていってね", ["またね", "はじめから あそぶ"])
            if choice == 1 {
                story.reset()
                await runner.blackOut(true)
                leave()
            }
        } else if story.has(.chapter3LetterDelivered) {
            await runner.say(.fumi, "サチちゃん、すっかりいい顔になったわね")
        } else if story.has(.unsentLetter) {
            await runner.say(.fumi, "銀河鉄道の終点には、物語を書いた人の思いが残っているかもしれないわ")
        } else {
            await runner.say(.fumi, "あの子、ずっと手紙をかかえてるの。……話を聞いてあげて")
        }
    }

    func talkToSachi() async {
        if story.has(.chapter3LetterDelivered) {
            await farewell()
        } else if story.has(.unsentLetter) {
            let choice = await runner.choose(.sachi, "もう一度、汽車に乗りに行こう？", ["本の中へ", "まだ"])
            if choice == 0 {
                await enterBook()
            }
        } else {
            await runner.say(.sachi, "……あ。こんばんは")
            await runner.say(.sachi, "わたし、サチ。この手紙……『銀河鉄道の夜』を書いた人に、出したかったの")
            await runner.say(.sachi, "書いたけど、切手を買いに行く前に……出せなくなっちゃった")
            await runner.say(.zunda, "ファンレターなのだ？")
            await runner.say(.sachi, "うん。……でも、作者さんは、わたしが生まれるずっと前に、もういなくなってたの")
            await runner.say(.sachi, "それでも、届けたかった。あの本、ほんとうに好きだったから")
            await runner.say(.fumi, "それなら、本の中の汽車に乗ってごらんなさい。終点まで行けば、きっと")
            story.give(.unsentLetter)
            story.set(.chapter3GotLetter)
            await runner.showItemGet(.unsentLetter)
            await runner.say(.sachi, "わたし、幽霊だから、本の中だと手紙が持てないの。……ずんだもんちゃん、持っていってくれる？")
            await runner.say(.zunda, "し、仕方ないのだ。両手でしっかり持つのだ")
            let choice = await runner.choose(.sachi, "……一緒に来てくれる？", ["本の中へ", "ちょっと待つのだ"])
            if choice == 0 {
                await enterBook()
            }
        }
    }

    // MARK: - 本の中

    private func enterBook() async {
        runner.passageSource = Self.source
        await runner.say(.fumi, "目を閉じて。ページの中へ……")
        await runner.blackOut(true, duration: 1.0)
        _ = openBook()
        await runner.quote("するとどこかで、ふしぎな声が、銀河ステーション、銀河ステーションと云う声がしたと思うといきなり眼の前が、ぱっと明るくなって、……ジョバンニは、思わず何べんも眼を擦ってしまいました。")
        await runner.blackOut(false, duration: 1.0)
        if !story.has(.chapter3TicketShown) {
            await runner.quote("ごとごとごとごと、その小さなきれいな汽車は、そらのすすきの風にひるがえる中を、天の川の水や、三角点の青じろい微光の中を、どこまでもどこまでもと、走って行くのでした。")
            await runner.say(.zunda, "き、汽車の中なのだ！ 窓の外が、星だらけなのだ！")
            await runner.say(.sachi, "銀河鉄道……！ ほんとうに乗れたんだ")
            await runner.say(.sachi, "この汽車の終点に、きっとあの人がいる。……手紙、落とさないでね")
            await runner.say(.zunda, "両手でかかえてるから、ほかに何も持てないのだ。気をつけるのだ")
        } else {
            await runner.say(.sachi, "また乗れたね。終点まで、行こう")
        }
    }

    // MARK: 一両目

    func giovanni() async {
        await runner.say(.giovanni, "きみたちも、この汽車でどこまでも行くの？")
        await runner.say(.zunda, "終点まで、手紙を届けに行くのだ")
        await runner.quote("「カムパネルラ、また僕たち二人きりになったねえ、どこまでもどこまでも一緒に行こう。」")
        await runner.say(.sachi, "（……ジョバンニだ。本で読んだとおりの声）")
    }

    func campanella() async {
        await runner.quote("「おっかさんは、ぼくをゆるして下さるだろうか。」\n\nいきなり、カムパネルラが、思い切ったというように、少しどもりながら、急きこんで云いました。")
        await runner.say(.zunda, "……なんだか、さびしそうな顔なのだ")
        await runner.say(.sachi, "カムパネルラはね……。ううん、なんでもない")
    }

    func conductor() async {
        guard let scene = book() else { return }
        if story.has(.chapter3TicketShown) {
            await runner.say(.conductor, "終点まで、ごゆっくり。")
            return
        }
        await runner.quote("「切符を拝見いたします。」")
        await runner.say(.zunda, "き、切符なんて持ってないのだ……！")
        guard scene.isCarryingLetter else {
            await runner.say(.sachi, "手紙を見せて！ ……あれ、置いてきちゃった？")
            return
        }
        await runner.say(.sachi, "その手紙を見せて。宛名が書いてあるから")
        await runner.say(.conductor, "……ふむ。『作者さまへ』。行き先の書いてある手紙ですな。")
        await runner.say(.conductor, "よろしい。それなら、終点まで乗っておいでなさい。")
        story.set(.chapter3TicketShown)
        await runner.say(.sachi, "やった……！ つぎの車両に行こう")
    }

    // MARK: 二両目

    func birdCatcher() async {
        guard let scene = book() else { return }
        await runner.quote("「こっちはすぐ喰べられます。どうです、少しおあがりなさい。」鳥捕りは、黄いろな雁の足を、軽くひっぱりました。するとそれは、チョコレートででもできているように、すっときれいにはなれました。")
        guard !scene.isCarryingLetter else {
            await runner.say(.zunda, "おいしそうなのだ……！ でも、両手がふさがってて受け取れないのだ……")
            await runner.say(.sachi, "手紙、どこかの座席にそっと置いたら？ あとで忘れずに拾ってね")
            return
        }
        await runner.quote("ジョバンニは、ちょっと喰べてみて、（なんだ、やっぱりこいつはお菓子だ。チョコレートよりも、もっとおいしいけれども、こんな雁が飛んでいるもんか。）")
        await runner.say(.zunda, "あまいのだ！ ずんだ餅の次においしいのだ！")
        story.set(.chapter3CandyEaten)
        await runner.say(.birdCatcher, "そうでしょう。……さて、わたしはそろそろ。")
        await scene.vanish(.birdCatcher)
        await runner.say(.zunda, "……あれ？ 消えちゃったのだ")
        await runner.say(.sachi, "鳥捕りさんは、本の中でもいつのまにかいなくなるの。……手紙、拾ってね")
    }

    // MARK: 三両目

    func lighthouseKeeper() async {
        guard let scene = book() else { return }
        if story.has(.chapter3AppleTaken) {
            await runner.say(.lighthouseKeeper, "いい旅を。")
            return
        }
        await runner.quote("「いかがですか。こういう苹果はおはじめてでしょう。」向うの席の燈台看守がいつか黄金と紅でうつくしくいろどられた大きな苹果を落さないように両手で膝の上にかかえていました。")
        await runner.say(.zunda, "燈台看守さんも、両手がふさがってるのだ。……ずんだもんとおそろいなのだ")
        guard !scene.isCarryingLetter else {
            await runner.say(.lighthouseKeeper, "おや、あなたも両手がふさがっておいでだ。")
            await runner.say(.zunda, "受け取りたいけど、手紙があるのだ……")
            return
        }
        await runner.say(.lighthouseKeeper, "いや、まあおとり下さい。どうか、まあおとり下さい。")
        story.give(.apple)
        story.set(.chapter3AppleTaken)
        await runner.showItemGet(.apple)
        await runner.quote("「けれどもほんとうのさいわいは一体何だろう。」ジョバンニが云いました。\n\n「僕わからない。」カムパネルラがぼんやり云いました。")
        await runner.say(.sachi, "わたし……それを、作者さんに聞いてみたかったの")
        await runner.say(.zunda, "ほんとうの、さいわい……")
        await runner.say(.sachi, "前の扉の向こうが、終点だよ。……手紙、忘れないでね")
    }

    // MARK: 座席と扉

    func seat(_ index: Int) async {
        guard let scene = book() else { return }
        if scene.isCarryingLetter {
            let choice = await runner.choose(.zunda, "手紙を、この座席にそっと置くのだ？", ["置く", "やめる"])
            if choice == 0 {
                scene.putLetter(on: index)
                await runner.say(.zunda, "これで両手があいたのだ。……あとで忘れずに拾うのだ")
            }
        } else if scene.letterSeat == index {
            scene.pickUpLetter()
            await runner.say(.zunda, "手紙を拾ったのだ。また両手でしっかりかかえるのだ")
        } else {
            await runner.say(.zunda, "空いている座席なのだ。ビロードがふかふかなのだ")
        }
    }

    func door(_ index: Int) async {
        guard let scene = book() else { return }
        guard !scene.openedDoors.contains(index) else { return }
        let episodeDone = [story.has(.chapter3TicketShown), story.has(.chapter3CandyEaten), story.has(.chapter3AppleTaken)][index]
        guard episodeDone else {
            let hints = [
                "扉の前に、車掌さんがこっちを見ているのだ……。切符を見せないとだめそうなのだ",
                "この車両の乗客と、まだ話していないのだ",
                "この車両の乗客と、まだ話していないのだ",
            ]
            await runner.say(.zunda, hints[index])
            return
        }
        guard !scene.isCarryingLetter else {
            await runner.say(.zunda, "重たい扉なのだ……。両手がふさがってて、開けられないのだ")
            await runner.say(.sachi, "手紙を、どこかの座席に置いてみたら？")
            return
        }
        scene.openDoor(index)
        await runner.say(.zunda, "よいしょっ……開いたのだ！")
        await runner.say(.sachi, "手紙、取りに戻ろう！")
    }

    /// 扉を抜けた先で、手紙を置き忘れていないか
    func doorway(_ index: Int) async {
        guard let scene = book() else { return }
        if let car = scene.letterCar, car <= index {
            await runner.say(.sachi, "待って！ 手紙、置いてきちゃってるよ！")
            scene.stepBack(from: index)
            return
        }
        if index == 2 && scene.isCarryingLetter && !story.has(.chapter3LetterDelivered) {
            await arriveAtTerminal()
        }
    }

    // MARK: 終点

    private func arriveAtTerminal() async {
        await runner.narrate("汽車は、しずかに止まったのだ。\nそこは、銀河のはての、\n小さな停車場だったのだ。")
        await runner.say(.sachi, "……あの人だ")
        await runner.say(.zunda, "帽子をかぶった人が、ひとりで星を見てるのだ")
    }

    func author() async {
        guard let scene = book() else { return }
        guard scene.isCarryingLetter else {
            await runner.say(.zunda, "手紙を持ってこないとなのだ！")
            return
        }
        await runner.say(.author, "……こんなところまで、お客さんとは。めずらしいことです")
        await runner.say(.sachi, "あ、あの……！ これ……読んでください！")
        await runner.say(.zunda, "サチからの手紙なのだ。ずんだもんが、ここまで運んできたのだ")
        await runner.say(.author, "わたしに、ですか")
        await runner.showHandwriting(Self.letter)
        await runner.say(.author, "…………")
        await runner.say(.author, "わたしの書いたものは、生きているうちは、ほとんど誰にも読まれませんでした")
        await runner.say(.author, "ほんとうに誰かに届いているのだろうか、と……ずっと、それだけが気がかりで、ここにいたのです")
        await runner.say(.author, "読んでくれた人が、いたのですね")
        await runner.say(.sachi, "……はい。なんども、なんども読みました")
        if story.has(.apple) {
            await runner.say(.zunda, "あ、あと、これ……燈台看守さんにもらった苹果なのだ。おみやげなのだ")
            story.take(.apple)
            await runner.say(.author, "ああ、わたしの書いた苹果だ。……ありがとう。いい匂いがします")
        }
        await runner.say(.author, "ほんとうのさいわいが何か、わたしにも、まだわからない。けれど……今、少しだけ分かった気がします")
        await runner.say(.author, "つづきは、あなたたちが読んでいってくれるのですね")
        story.take(.unsentLetter)
        story.set(.chapter3LetterDelivered)
        await scene.glowAuthorAndSachi()
        await runner.say(.sachi, "……届いた。わたしの手紙、届いたよ")
        await scene.authorFadesAway()
        await runner.say(.zunda, "……星に、とけていったのだ")
        await runner.blackOut(true, duration: 1.0)
        closeBook()
        runner.passageSource = ""
        await runner.blackOut(false, duration: 1.0)
        await farewell()
    }

    // MARK: - 図書室にもどって

    private func farewell() async {
        library.makeSachiHappy()
        await runner.say(.sachi, "ありがとう、ずんだもんちゃん。会ったことのない人に、ちゃんと届いた")
        await runner.say(.sachi, "本って、ふしぎだね。……会ったこともない人と、つながってるみたい")
        await runner.say(.sachi, "じゃあね。わたしも、ほんとうのさいわい、さがしに行ってくる")
        story.set(.chapter3SachiPassed)
        await library.ascendSachi()
        await runner.say(.fumi, "本はね、会ったことのない人と人を、つないでくれるのよ")
        await runner.say(.fumi, "書いた人と、読んだ人。読んだ人と、つぎに読む人。……ずっと、ね")
        await runner.say(.zunda, "……つぎに読む人")
        await runner.say(.zunda, "（おフミさんにも、何か書いてみようかな……なのだ）")
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは、\n部屋のすみで小さなカードを取り出したのだ。")
        story.setMemo("書きかけ", for: Self.memoKey)
        await runner.showHandwriting([HandwrittenNote(text: "おフミさんへ。\n本のことは、まだよくわからないけど、")])
        await runner.narrate("……つづきは、まだ書けなかったのだ。\nカードは、こっそり机の引き出しにしまったのだ。")
        story.set(.chapter3Cleared)
        await runner.chapterTitle("第3章 おわり", "手紙は届くのだ")
        await runner.narrate("つぎのお話「声に出すと、もっと楽しいのだ」は、\nまた夜になったら始まるのだ。")
        leave()
    }

    func exit() async {
        if story.has(.chapter3Cleared) {
            await runner.blackOut(true)
            leave()
            return
        }
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "あら、もう帰っちゃうの？ ……サチちゃん、待ってるわよ")
        await runner.blackOut(true)
        leave()
    }
}
