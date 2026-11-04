import Foundation

/// 第2章「書き込みは、その人の足あとなのだ」のイベント。
/// 飼い主のキヨさんに読み聞かせてもらった時間が忘れられない猫の幽霊・タマと、
/// 『吾輩は猫である』の本の中でキヨさんの書き込みを辿る。
/// 本の中の一節は青空文庫の『吾輩は猫である』（夏目漱石）から引用している
struct Chapter2Events {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 本の中へ入る。作った本の中のマップを返す
    let openBook: () -> NekoScene
    /// 本を閉じて図書室に戻る
    let closeBook: () -> Void
    let book: () -> NekoScene?
    /// 部屋に帰る
    let leave: () -> Void

    static let source = "『吾輩は猫である』夏目漱石"
    static let memoKey = "吾輩は猫である"

    static let readAloudBook = PictureBook(title: "吾輩は猫である", pages: [
        PictureBookPage(imageName: "sprite_neko_page_name", text: "吾輩は猫である。名前はまだ無い。\nどこで生れたかとんと見当がつかぬ。何でも薄暗いじめじめした所でニャーニャー泣いていた事だけは記憶している。"),
        PictureBookPage(imageName: "sprite_neko_page_mochi", text: "「あら猫が御雑煮を食べて踊を踊っている」と大きな声をする。"),
        PictureBookPage(imageName: "sprite_neko_page_lap", text: "名前はまだつけてくれないが、欲をいっても際限がないから生涯この教師の家で無名の猫で終るつもりだ。"),
    ])

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.chapter2Cleared) {
            return "夜の図書室なのだ。つぎのお話は、まだ準備中なのだ"
        } else if story.has(.chapter2NoteBrazier) {
            return "タマに、本を読んであげるのだ"
        } else if story.has(.annotatedBook) {
            return "タマと一緒に、本の中のキヨさんの書き込みを辿るのだ"
        } else if story.has(.chapter2Started) {
            return "閲覧机の上の、猫の幽霊に話しかけるのだ"
        }
        return "夜の図書室なのだ"
    }

    /// 本の中にいるときの「いまやること」
    static func bookObjective(_ progress: NoteProgress) -> String {
        if progress.count >= NoteProgress.total - 1 {
            return "茶の間の火鉢のあたりで、最後の書き込みが光っているのだ"
        }
        return "家のあちこちで、キヨさんの書き込みを探すのだ（書斎・台所・隣の縁側…）"
    }

    // MARK: - 図書室

    func arrive() async {
        if !story.has(.chapter2Started) {
            await opening()
        } else if !story.has(.chapter2Cleared) {
            await runner.say(.fumi, "おかえりなさい。タマちゃん、机の上で待ってるわよ")
        }
    }

    private func opening() async {
        await runner.chapterTitle("第2章", "書き込みは、その人の足あとなのだ")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.fumi, "いらっしゃい、ずんだもんちゃん。今夜のお客さんは……ちょっと小さいわね")
        await runner.say(.zunda, "閲覧机の上に、猫がいるのだ。……透けてるのだ")
        await runner.say(.fumi, "本を一冊、だいじそうに抱えてるの。話を聞いてあげて")
        story.set(.chapter2Started)
    }

    func talkToFumi() async {
        if story.has(.chapter2Cleared) {
            await runner.say(.fumi, "今夜は静かね。……つぎのお客さんは、まだみたい")
            await runner.say(.zunda, "べ、別におフミさんに会いに来たわけじゃないのだ")
            let choice = await runner.choose(.fumi, "ふふ。ゆっくりしていってね", ["またね", "はじめから あそぶ"])
            if choice == 1 {
                story.reset()
                await runner.blackOut(true)
                leave()
            }
        } else if story.has(.chapter2NoteBrazier) {
            await runner.say(.fumi, "タマちゃんに、読んであげて。キヨさんのかわりに")
        } else if story.has(.annotatedBook) {
            await runner.say(.fumi, "書き込みはね、その人がその本を読んだ足あとなの。辿っていけば、きっと会えるわ")
        } else {
            await runner.say(.fumi, "猫ちゃんの幽霊なんて、めずらしいわね。……かわいい")
        }
    }

    func talkToTama() async {
        if story.has(.chapter2NoteBrazier) {
            await readToTama()
        } else if story.has(.annotatedBook) {
            let choice = await runner.choose(.tama, "吾輩は、もう一度あの本の中へ行きたい", ["本の中へ", "まだ"])
            if choice == 0 {
                await enterBook()
            }
        } else {
            await runner.say(.tama, "……吾輩はタマである。名前は、もうある")
            await runner.say(.zunda, "ね、猫がしゃべったのだ！")
            await runner.say(.tama, "幽霊だから、しゃべりもする。……名前はキヨさんがつけてくれた")
            await runner.say(.tama, "キヨさんは毎晩、ひざの上の吾輩に、この本を読んでくれた。『吾輩は猫である』という本だ")
            await runner.say(.tama, "けれど、ある晩からキヨさんの声は、だんだん小さくなって……つづきは、聞けないままになった")
            await runner.say(.tama, "吾輩は、もう一度あの時間に戻りたいのだ。キヨさんのひざの上の、あの時間に")
            await runner.say(.zunda, "…………")
            story.give(.annotatedBook)
            story.set(.chapter2GotBook)
            await runner.showItemGet(.annotatedBook)
            await runner.say(.fumi, "あら、書き込みだらけね。……傍線に、『ここ笑った』の字。キヨさんの足あとよ")
            await runner.say(.fumi, "本の中で、書き込みを辿ってごらんなさい。キヨさんがどんなふうにこの本を読んだのか、きっと分かるわ")
            let choice = await runner.choose(.tama, "……一緒に来てくれるか", ["本の中へ", "ちょっと待つのだ"])
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
        await runner.narrate("気がつくと、ずんだもんは\n小さな庭の、杉垣のそばにいたのだ。")
        await runner.blackOut(false, duration: 1.0)
        if !story.has(.chapter2NoteHedge) {
            await runner.quote("吾輩は猫である。名前はまだ無い。")
            await runner.say(.zunda, "……手が、もふもふなのだ。しっぽもあるのだ！？")
            await runner.say(.zunda, "ずんだもん、猫になってるのだ！！")
            await runner.say(.tama, "この本の中では、猫の目で見るのがいちばんだ。ここは『吾輩』の主人、苦沙弥先生の家だ")
            await runner.say(.tama, "……足もとを見ろ。何か光っている")
        } else {
            await runner.say(.tama, "さあ、キヨさんの足あとを探そう")
        }
    }

    /// 書き込み①: 杉垣のそば。キヨさんが若いころの字と、もう一人の字
    func hedgeNote() async {
        guard let scene = book() else { return }
        scene.collectNote(at: .hedgeNote)
        story.set(.chapter2NoteHedge)
        await runner.showHandwriting([
            HandwrittenNote(text: "十六の春。フミちゃんに借りた本。\n猫の気持ちになって読むと、おもしろい。"),
            HandwrittenNote(text: "名前がないなんて、かわいそうね。\nキヨちゃんなら、なんてつける？　――ふみ", isOtherHand: true),
        ])
        await runner.say(.zunda, "下のほう、ちがう字なのだ……。「ふみ」って書いてあるのだ")
        await runner.say(.tama, "それはキヨさんの字ではない。……キヨさんは、ときどきこのページをなでていた")
        await runner.say(.zunda, "（ふみ……？）")
        await afterNote()
    }

    /// 書き込み②: 書斎で昼寝する主人。お嫁に来たころ
    func master() async {
        guard let scene = book() else { return }
        guard !story.has(.chapter2NoteStudy) else {
            await runner.say(.zunda, "ぐうぐう寝ているのだ。鼻ちょうちんが出たり引っこんだりしているのだ")
            return
        }
        await runner.quote("吾輩は時々忍び足に彼の書斎を覗いて見るが、彼はよく昼寝をしている事がある。時々読みかけてある本の上に涎をたらしている。")
        await runner.say(.zunda, "ほんとに本の上で寝てるのだ……。よだれが垂れてるのだ")
        await runner.say(.zunda, "……ずんだもんも、字を見るとすぐ眠くなるから、ちょっと気持ちは分かるのだ")
        await scene.wakeMaster()
        await runner.quote("二三ページ読むと眠くなる。涎を本の上へ垂らす。これが彼の毎夜繰り返す日課である。")
        scene.collectNote(at: .master)
        story.set(.chapter2NoteStudy)
        await runner.showHandwriting([
            HandwrittenNote(text: "お嫁に来た冬。\nうちの人も、本を読むとすぐ寝てしまう。\nそっくりで、ひとりで笑った。"),
        ])
        await runner.say(.tama, "キヨさんの旦那さんは、吾輩が来る前に、先に旅立ったと聞いている")
        await runner.say(.tama, "キヨさんはこのページを読むと、いつも少しだけ笑った")
        await afterNote()
    }

    /// 書き込み③: 台所の雑煮。タマがうちに来たころ
    func zouni() async {
        guard let scene = book() else { return }
        guard !story.has(.chapter2NoteKitchen) else {
            await runner.say(.zunda, "もう餅はこりごりなのだ……")
            return
        }
        await runner.quote("今朝見た通りの餅が、今朝見た通りの色で椀の底に膠着している。白状するが餅というものは今まで一辺も口に入れた事がない。")
        let choice = await runner.choose(.zunda, "お雑煮の残りなのだ。……ちょっとだけ、食べてみるのだ？", ["たべる", "やめておく"])
        guard choice == 0 else {
            await runner.say(.tama, "……キヨさんの書き込みは、たぶん、食べないと出てこない")
            return
        }
        await runner.quote("最後にからだ全体の重量を椀の底へ落すようにして、あぐりと餅の角を一寸ばかり食い込んだ。")
        await runner.say(.zunda, "んぐっ！？ は、歯にくっついて取れないのだ！！")
        await scene.danceWithMochi()
        await runner.quote("とうとう小供に見付けられた。「あら猫が御雑煮を食べて踊を踊っている」と大きな声をする。")
        await runner.say(.zunda, "はぁ、はぁ……やっと取れたのだ……。ずんだ餅なら大歓迎なのに……")
        scene.collectNote(at: .zouni)
        story.set(.chapter2NoteKitchen)
        await runner.showHandwriting([
            HandwrittenNote(text: "ここ笑った。\nうちにも猫が来た。タマと名づける。\nお正月、お餅をやったら、ほんとうに踊った。"),
        ])
        await runner.say(.tama, "……吾輩、踊ったことがある")
        await runner.say(.zunda, "タマもなのだ！？")
        await runner.say(.tama, "キヨさんは涙が出るほど笑って、そのあと、餅を取ってくれた。……あれは、ひどい目にあった")
        await afterNote()
    }

    /// 書き込み④: 隣の縁側の三毛子。キヨさんが年をとってから
    func mikeko() async {
        guard let scene = book() else { return }
        guard !story.has(.chapter2NoteMikeko) else {
            await runner.say(.mikeko, "あら先生、ごきげんよう")
            return
        }
        await runner.quote("杉垣の隙から、いるかなと思って見渡すと、三毛子は正月だから首輪の新しいのをして行儀よく椽側に坐っている。")
        await runner.say(.mikeko, "あら先生、おめでとう")
        await runner.say(.zunda, "せ、先生……？ ずんだもんのことなのだ？")
        await runner.quote("町内で吾輩を先生と呼んでくれるのはこの三毛子ばかりである。")
        await runner.say(.mikeko, "ええ去年の暮御師匠さんに買って頂いたの、宜いでしょう")
        await runner.say(.zunda, "首輪の鈴が、ちりんちりん鳴ってるのだ。きれいなのだ")
        scene.collectNote(at: .mikeko)
        story.set(.chapter2NoteMikeko)
        await runner.showHandwriting([
            HandwrittenNote(text: "目がわるくなって、虫めがねで読む。\n字が大きくゆれる。\nタマがひざで、ごろごろいう。"),
        ])
        await runner.say(.tama, "キヨさんの字が、ゆれている……")
        await runner.say(.tama, "このころには、本を読む声も、ゆっくりになっていた。吾輩は、そのゆっくりな声が好きだった")
        await afterNote()
    }

    func brazier() async {
        guard let scene = book() else { return }
        guard scene.progress.count >= NoteProgress.total - 1 else {
            await runner.say(.zunda, "火鉢であったまってる場合じゃないのだ。書き込みを探すのだ")
            return
        }
        scene.collectNote(at: .brazier)
        story.set(.chapter2NoteBrazier)
        await runner.quote("吾輩は御馳走も食わないから別段肥りもしないが、まずまず健康で跛にもならずにその日その日を暮している。")
        await runner.showHandwriting([
            HandwrittenNote(text: "タマへ。\nきょうは、ここまで。\nつづきは、また明日ね。"),
        ])
        await runner.say(.tama, "……ここだ。キヨさんが、最後に読んでくれたところ")
        await runner.say(.tama, "『また明日ね』の、明日は……来なかった")
        await runner.say(.zunda, "…………")
        await runner.say(.zunda, "タマ。……つづき、ずんだもんが読むのだ")
        await runner.say(.zunda, "字を見ると眠くなるけど、がんばって読むのだ")
        await runner.say(.tama, "……うむ")
        await runner.blackOut(true, duration: 1.0)
        closeBook()
        runner.passageSource = ""
        await runner.blackOut(false, duration: 1.0)
        await readToTama()
    }

    func kamado() async {
        await runner.say(.zunda, "大きなお釜なのだ。ごはんのいいにおいがするのだ")
    }

    func table() async {
        await runner.say(.zunda, "湯のみがひとつ。……誰かが、お茶を飲みながら本を読んでたのだ？")
    }

    private func afterNote() async {
        guard let scene = book() else { return }
        let remaining = NoteProgress.total - 1 - scene.progress.count
        if remaining > 0 {
            await runner.say(.zunda, "書き込みは、あと\(remaining)つくらいありそうなのだ")
        } else {
            await runner.say(.tama, "……茶の間のほうで、何かが光った")
        }
    }

    // MARK: - 図書室にもどって

    /// キヨさんのかわりに、ずんだもんがタマに読み聞かせる
    private func readToTama() async {
        await runner.say(.zunda, "じゃあ……読むのだ。ひざの上、来てもいいのだ")
        await runner.say(.tama, "……では、失礼する")
        await runner.readPictureBook(Self.readAloudBook)
        await runner.say(.tama, "…………")
        await runner.say(.tama, "キヨさんの声とは、ちがう。……でも、あったかい")
        await runner.say(.tama, "吾輩は、無名の猫ではなかった。キヨさんが、タマと呼んでくれた")
        await runner.say(.tama, "……ありがとう、ずんだもん。吾輩は、キヨさんのところへ行く")
        story.take(.annotatedBook)
        story.set(.chapter2TamaPassed)
        await library.ascendTama()
        await runner.say(.zunda, "……ひざが、まだあったかいのだ")
        await runner.say(.zunda, "おフミさん。最初の書き込みの、ちがう字……「ふみ」って書いてあったのだ")
        await runner.say(.fumi, "…………")
        await runner.say(.fumi, "……昔の、ともだちの本よ。キヨちゃんに、あの本を貸したのは、わたし")
        await runner.say(.fumi, "ずいぶん、大事にしてくれてたのね。……ほんとうに")
        await runner.say(.zunda, "おフミさん……")
        await runner.say(.fumi, "さ、しんみりするのはおしまい！ ……ずんだ餅が食べたいわねえ")
        await runner.say(.zunda, "ここで餅の話はやめてほしいのだ……")
        await writeOwnNote()
    }

    /// ずんだもんも、自分の本に小さく書き込む
    private func writeOwnNote() async {
        await runner.say(.zunda, "……ずんだもんも、ちょっとだけ書き込んでみるのだ。本のすみっこに、小さく")
        let options = ["ここ笑った", "タマ、またね", "ずんだもんも読んだのだ"]
        let choice = await runner.choose(.zunda, "なんて書くのだ？", options)
        let memo = options[choice]
        story.setMemo(memo, for: Self.memoKey)
        await runner.showHandwriting([HandwrittenNote(text: memo)])
        await runner.say(.fumi, "……すてきな足あとね")
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは自分の『吾輩は猫である』の\nすみっこに、小さく書き込んだのだ。")
        await runner.narrate("いつか誰かが、\nこの字を見つけてくれるかもしれないのだ。")
        story.set(.chapter2Cleared)
        await runner.chapterTitle("第2章 おわり", "書き込みは、その人の足あとなのだ")
        await runner.narrate("つぎのお話「手紙は届くのだ」は、\nまた夜になったら始まるのだ。")
        leave()
    }

    func exit() async {
        if story.has(.chapter2Cleared) {
            await runner.blackOut(true)
            leave()
            return
        }
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "あら、もう帰っちゃうの？ ……タマちゃん、待ってるわよ")
        await runner.blackOut(true)
        leave()
    }
}
