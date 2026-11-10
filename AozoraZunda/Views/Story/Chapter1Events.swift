import Foundation

/// 第1章「続きが気になるのだ」のイベント。
/// 『走れメロス』の結末を知らないまま亡くなった中学生の幽霊・タクと、本の中へ結末を確かめに行く。
/// 本の中の一節は青空文庫の『走れメロス』（太宰治）から引用している
struct Chapter1Events {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 本の中へ入る。作った本の中のマップを返す
    let openBook: () -> MelosScene
    /// 本を閉じて図書室に戻る
    let closeBook: () -> Void
    /// いま開いている本の中のマップ
    let book: () -> MelosScene?
    /// 部屋に帰る
    let leave: () -> Void

    static let source = "『走れメロス』太宰治"

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.chapter1Cleared) {
            return "夜の図書室なのだ。つぎのお話は、まだ準備中なのだ"
        } else if story.has(.chapter1ReachedEnd) {
            return "タクに声をかけるのだ"
        } else if story.has(.ticketBookmark) {
            return "しおりをタクに届けるのだ"
        } else if story.has(.chapter1AskedBookmark) {
            return "タクのしおりを探すのだ。カウンターのあたりで何か光っているのだ"
        } else if story.has(.chapter1Started) {
            return "閲覧机のタクに話しかけるのだ"
        }
        return "夜の図書室なのだ"
    }

    /// 本の中にいるときの「いまやること」
    static func bookObjective(_ story: StoryStore, clock: SunsetClock) -> String {
        if clock.isMelosDown {
            return "どこかで水の音がするのだ…岩のあたりを調べるのだ"
        } else if story.has(.chapter1PhilostratusPassed) {
            return "シラクスの城門へ走るのだ！"
        } else if story.has(.chapter1MelosRevived) {
            return "シラクスの町まで、あと少しなのだ！"
        } else if story.has(.chapter1BanditsPassed) {
            return "峠を下って、道を北へ進むのだ"
        } else if story.has(.chapter1RiverCrossed) {
            return "峠をこえるのだ。日没までにシラクスへ！"
        }
        return "道を北へ進むのだ。日没までにシラクスへ！"
    }

    // MARK: - 図書室

    /// 第1章が始まってから図書室に来たとき
    func arrive() async {
        if !story.has(.chapter1Started) {
            await opening()
        } else if !story.has(.chapter1Cleared) {
            await runner.say(.fumi, "おかえりなさい。タクくんが待ってるわよ")
        }
    }

    private func opening() async {
        await runner.chapterTitle("第1章", "続きが気になるのだ")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.fumi, "いらっしゃい。……ふふ、来ると思ってたわ")
        await runner.say(.zunda, "雨宿りなのだ。たまたまなのだ")
        await runner.say(.fumi, "今夜のお客さんは、あの子よ。閲覧机のところ")
        await runner.say(.zunda, "……学ランの幽霊なのだ。本をじっと見てるのだ")
        story.set(.chapter1Started)
    }

    func talkToFumi() async {
        if story.has(.chapter1Cleared) {
            await runner.say(.fumi, "今夜は静かね。……つぎのお客さんは、まだみたい")
            await runner.say(.zunda, "べ、別におフミさんに会いに来たわけじゃないのだ")
            let choice = await runner.choose(.fumi, "ふふ。ゆっくりしていってね", ["またね", "はじめから あそぶ"])
            if choice == 1 {
                story.reset()
                await runner.blackOut(true)
                leave()
            }
        } else if story.has(.chapter1ReachedEnd) {
            await runner.say(.fumi, "タクくん、ずいぶんすっきりした顔をしてるわね")
        } else if story.has(.ticketBookmark) {
            await runner.say(.fumi, "しおりを挟んだページからなら、本の中に入れるわ。タクくんに渡してあげて")
        } else if story.has(.chapter1AskedBookmark) {
            await runner.say(.fumi, "しおり？ そういえば、カウンターのそばで何か光っていたような……")
        } else {
            await runner.say(.fumi, "タクくん、ずっとあの本とにらめっこしてるの。話を聞いてあげて")
        }
    }

    func talkToTaku() async {
        if story.has(.chapter1ReachedEnd) {
            await farewell()
        } else if story.has(.tatteredBook) {
            let choice = await runner.choose(.taku, "本の中、もう一回行ける？", ["本の中へ", "まだ"])
            if choice == 0 {
                await enterBook()
            }
        } else if story.has(.ticketBookmark) {
            await runner.say(.taku, "それ！ ぼくの切符。……通学の電車で、いつもこれを挟んで読んでたんだ")
            story.take(.ticketBookmark)
            story.give(.tatteredBook)
            await runner.showItemGet(.tatteredBook)
            await runner.say(.fumi, "しおりのページからなら、本の中に入れるのよ。夜の司書の特技なの")
            await runner.say(.zunda, "ほ、本の中！？")
            await runner.say(.fumi, "結末は、本の中で確かめてらっしゃい。タクくんも一緒にね")
            await runner.say(.fumi, "ただし、物語の時間は止まってくれないわ。日が沈む前に、シラクスへ")
            let choice = await runner.choose(.taku, "……いっしょに来てくれる？", ["本の中へ", "ちょっと待つのだ"])
            if choice == 0 {
                await enterBook()
            }
        } else if story.has(.chapter1AskedBookmark) {
            await runner.say(.taku, "しおり、見つかった……？")
        } else {
            await runner.say(.taku, "あ……こんばんは。きみも、ここの人？")
            await runner.say(.zunda, "見習いなのだ。……不本意なのだ")
            await runner.say(.taku, "ぼく、タク。この本……『走れメロス』を読んでたんだ")
            await runner.say(.taku, "でも、川のところから先がやぶれてて。メロスが間に合ったのか、わかんないまま……")
            await runner.say(.zunda, "それで成仏できないのだ……？")
            await runner.say(.taku, "うん。続きが気になって。……それに、しおりも、どこかに落としちゃったんだ")
            await runner.say(.zunda, "しおりなら、ずんだもんが探してくるのだ。……ちょっとだけなのだ")
            story.set(.chapter1AskedBookmark)
            library.showTakuBookmarkSparkle()
        }
    }

    func pickUpTakuBookmark() async {
        library.removeTakuBookmarkSparkle()
        story.give(.ticketBookmark)
        story.set(.chapter1FoundBookmark)
        await runner.showItemGet(.ticketBookmark)
        await runner.say(.zunda, "切符なのだ。……これをしおりにしてたのだ？")
    }

    func exit() async {
        if story.has(.chapter1Cleared) {
            await runner.blackOut(true)
            leave()
            return
        }
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "あら、もう帰っちゃうの？ ……タクくん、待ってるわよ")
        await runner.blackOut(true)
        leave()
    }

    // MARK: - 本の中

    private func enterBook() async {
        runner.passageSource = Self.source
        await runner.say(.fumi, "目を閉じて。ページの中へ……")
        await runner.blackOut(true, duration: 1.0)
        let scene = openBook()
        await runner.narrate("気がつくと、ずんだもんは\n見知らぬ野原に立っていたのだ。")
        await runner.blackOut(false, duration: 1.0)
        if !story.has(.chapter1RiverCrossed) {
            await runner.say(.melos, "君たちは誰だ？ ……いや、名を聞いている暇はない。私は日没までに、シラクスへ戻らねばならぬのだ")
            await runner.say(.taku, "メロスだ……！ 本物のメロスだ！")
            await runner.say(.zunda, "ずんだもんたちも、ついて行くのだ！")
        } else {
            await runner.say(.melos, "さあ、急ごう。陽は待ってはくれぬ")
        }
        _ = scene
    }

    /// 濁流の前に来たとき
    func river() async {
        guard let scene = book() else { return }
        await runner.quote("見よ、前方の川を。きのうの豪雨で山の水源地は氾濫し、濁流滔々と下流に集り、猛勢一挙に橋を破壊し、どうどうと響きをあげる激流が、木葉微塵に橋桁を跳ね飛ばしていた。")
        await runner.say(.melos, "ああ、鎮めたまえ、荒れ狂う流れを！　時は刻々に過ぎて行きます。")
        await runner.say(.taku, "ぼくが読めたの、ここまでなんだ。この先のページは、やぶれてて……")
        await runner.say(.zunda, "メロスは、ここでどうするのだ……？")
        await fillIn(
            "今はメロスも覚悟した。【　　　】より他に無い。",
            options: ["舟を待つ", "泳ぎ切る", "引き返す"],
            answer: 1,
            wrong: "メロスなら、きっとそうはしないと思うんだ……"
        )
        await runner.quote("メロスは、ざんぶと流れに飛び込み、百匹の大蛇のようにのた打ち荒れ狂う浪を相手に、必死の闘争を開始した。")
        await runner.blackOut(true)
        scene.crossRiver()
        story.set(.chapter1RiverCrossed)
        await runner.blackOut(false)
        await runner.quote("押し流されつつも、見事、対岸の樹木の幹に、すがりつく事が出来たのである。")
        await runner.say(.zunda, "ぷはっ！ お、泳ぎ切ったのだ……びしょびしょなのだ")
        await runner.say(.taku, "ぼく、幽霊だから濡れてないや")
        await runner.say(.zunda, "ずるいのだ！")
    }

    /// 峠で山賊に囲まれたとき
    func bandits() async {
        guard let scene = book() else { return }
        await scene.showBandits()
        await runner.quote("ぜいぜい荒い呼吸をしながら峠をのぼり、のぼり切って、ほっとした時、突然、目の前に一隊の山賊が躍り出た。")
        await runner.say(.melos, "何をするのだ。私は陽の沈まぬうちに王城へ行かなければならぬ。放せ。")
        await runner.quote("「どっこい放さぬ。持ちもの全部を置いて行け。」")
        await runner.say(.melos, "私にはいのちの他には何も無い。その、たった一つの命も、これから王にくれてやるのだ。")
        await fillIn(
            "「気の毒だが【　　】のためだ！」と猛然一撃、たちまち、三人を殴り倒し、",
            options: ["お金", "正義", "王様"],
            answer: 1,
            wrong: "メロスが戦うのは、そんな理由じゃないよ……"
        )
        await scene.chaseOffBandits()
        story.set(.chapter1BanditsPassed)
        await runner.quote("残る者のひるむ隙に、さっさと走って峠を下った。")
        await runner.say(.zunda, "け、けんかはよくないのだ……。でも、本の中だから仕方ないのだ")
    }

    /// 峠を下りきったところで、メロスが倒れる
    func collapse() async {
        guard let scene = book() else { return }
        scene.collapseMelos()
        await runner.quote("一気に峠を駈け降りたが、流石に疲労し、折から午後の灼熱の太陽がまともに、かっと照って来て、メロスは幾度となく眩暈を感じ、……ついに、がくりと膝を折った。")
        await runner.say(.melos, "ああ、もう、どうでもいい。これが、私の定った運命なのかも知れない。")
        await runner.say(.taku, "メロス……ここで、あきらめちゃうの……？")
        await runner.say(.zunda, "しっかりするのだ！ ……なにか、元気が出るものがあればいいのだ")
        await runner.quote("ふと耳に、潺々、水の流れる音が聞えた。")
        await runner.say(.zunda, "水の音……？ どこかの岩のあたりから聞こえるのだ")
    }

    func examineRock(_ index: Int) async {
        guard let scene = book() else { return }
        guard scene.clock.isMelosDown else {
            await runner.say(.zunda, index == MelosInteractable.springRock ? "岩に、細い裂け目があるのだ" : "ごつごつした岩なのだ")
            return
        }
        guard index == MelosInteractable.springRock else {
            await runner.say(.zunda, "ただの岩なのだ……。水の音は、ここじゃないのだ")
            return
        }
        scene.revealSpring()
        await runner.quote("見ると、岩の裂目から滾々と、何か小さく囁きながら清水が湧き出ているのである。")
        await runner.say(.zunda, "あったのだ！ メロス、水なのだ！")
        await scene.reviveMelos()
        await runner.quote("水を両手で掬って、一くち飲んだ。ほうと長い溜息が出て、夢から覚めたような気がした。歩ける。行こう。")
        await fillIn(
            "私は、信頼に報いなければならぬ。いまはただその一事だ。【　　】！　メロス。",
            options: ["止まれ", "眠れ", "走れ"],
            answer: 2,
            wrong: "ちがうよ、ここは……あの言葉だよ！"
        )
        story.set(.chapter1MelosRevived)
        await runner.say(.taku, "走れ、メロス……！")
    }

    func talkToLyingMelos() async {
        await runner.say(.melos, "私は、よくよく不幸な男だ。……放って置いてくれ。")
        await runner.say(.zunda, "水の音がするのだ。どこかの岩なのだ……")
    }

    /// フィロストラトスが追いかけてくる
    func philostratus() async {
        guard let scene = book() else { return }
        await runner.quote("「ああ、メロス様。」うめくような声が、風と共に聞えた。")
        await runner.quote("「もう、駄目でございます。むだでございます。走るのは、やめて下さい。もう、あの方をお助けになることは出来ません。」")
        await runner.say(.melos, "いや、まだ陽は沈まぬ。")
        await runner.quote("「あの方は、あなたを信じて居りました。刑場に引き出されても、平気でいました。」")
        await fillIn(
            "「それだから、走るのだ。【　　　　　】から走るのだ。間に合う、間に合わぬは問題でないのだ。」",
            options: ["間に合う", "信じられている", "命令された"],
            answer: 1,
            wrong: "メロスが走るのは……誰かのためだったよね"
        )
        scene.passPhilostratus()
        story.set(.chapter1PhilostratusPassed)
        await runner.say(.melos, "ついて来い！　フィロストラトス。")
        await runner.say(.zunda, "見えたのだ！ シラクスの城門なのだ！")
    }

    /// 城門に飛び込み、結末を見届ける
    func gate() async {
        guard let scene = book() else { return }
        scene.isClockRunning = false
        await runner.quote("陽は、ゆらゆら地平線に没し、まさに最後の一片の残光も、消えようとした時、メロスは疾風の如く刑場に突入した。間に合った。")
        await runner.blackOut(true, duration: 0.5)
        await scene.enterExecutionGround()
        await runner.blackOut(false, duration: 0.5)
        await runner.say(.melos, "私だ、刑吏！　殺されるのは、私だ。メロスだ。彼を人質にした私は、ここにいる！")
        await runner.quote("群衆は、どよめいた。あっぱれ。ゆるせ、と口々にわめいた。セリヌンティウスの縄は、ほどかれたのである。")
        await scene.freeSelinuntius()
        await runner.say(.melos, "セリヌンティウス。私を殴れ。ちから一ぱいに頬を殴れ。私は、途中で一度、悪い夢を見た。君が若し私を殴ってくれなかったら、私は君と抱擁する資格さえ無いのだ。殴れ。")
        await runner.say(.selinuntius, "メロス、私を殴れ。同じくらい音高く私の頬を殴れ。私はこの三日の間、たった一度だけ、ちらと君を疑った。生れて、はじめて君を疑った。")
        await scene.embrace()
        await runner.quote("「ありがとう、友よ。」二人同時に言い、ひしと抱き合い、それから嬉し泣きにおいおい声を放って泣いた。")
        await runner.quote("「おまえらの望みは叶ったぞ。おまえらは、わしの心に勝ったのだ。信実とは、決して空虚な妄想ではなかった。どうか、わしをも仲間に入れてくれまいか。」")
        await runner.quote("勇者は、ひどく赤面した。")
        story.set(.chapter1ReachedEnd)
        await runner.say(.taku, "……間に合ったんだ。メロス、間に合ったんだ！")
        await runner.say(.taku, "よかった……。ぼく、ずっと、それだけが気になってたんだ")
        await runner.say(.zunda, "……よかったのだ。（ぐすっ）")
        await runner.say(.zunda, "な、泣いてないのだ！ 雨なのだ！")
        await runner.say(.taku, "本の中、晴れてるよ")
        await runner.blackOut(true, duration: 1.0)
        closeBook()
        runner.passageSource = ""
        await runner.blackOut(false, duration: 1.0)
        await farewell()
    }

    /// 時間切れ。少し前のページから読み直す
    func timeUp() async {
        guard let scene = book() else { return }
        await runner.quote("陽が、沈んでしまった……。")
        await runner.say(.taku, "そんな……間に合わなかった……")
        await runner.say(.fumi, "（大丈夫。本は、何度でも読み返せるのよ。少し前のページから、もう一度）")
        await runner.blackOut(true)
        scene.rewind()
        await runner.blackOut(false)
        await runner.say(.zunda, "ページが戻ったのだ……！ 今度こそ、急ぐのだ！")
    }

    /// 虫食いの一節。正しい言葉を選ぶまで繰り返し、間違えると日が少し傾く
    private func fillIn(_ text: String, options: [String], answer: Int, wrong: String) async {
        while await runner.fillInBlank(text, options) != answer {
            await runner.say(.taku, wrong)
            book()?.spendTime(10)
            await runner.say(.zunda, "うう、日が傾いてきたのだ……。もう一回なのだ")
        }
    }

    // MARK: - 図書室にもどって

    private func farewell() async {
        library.makeTakuHappy()
        await runner.say(.taku, "ありがとう、ずんだもん。おかげで、最後まで読めたよ")
        await runner.say(.taku, "……ちっちゃいころさ、この図書館で、本を読み聞かせしてくれるおばあちゃんがいたんだ")
        await runner.say(.taku, "ぼくが本を好きになったの、その人のおかげなんだ")
        await runner.say(.fumi, "…………")
        await runner.say(.fumi, "……そう。その人、きっと喜んでるわ")
        await runner.say(.taku, "続きが気になって眠れないのって、ひさしぶりだった。……じゃあね")
        story.take(.tatteredBook)
        await library.ascendTaku()
        await runner.say(.zunda, "……行っちゃったのだ")
        await runner.say(.fumi, "その本、ちゃんとした版が棚にあるわよ。……気になる？")
        await runner.say(.zunda, "き、気にならないのだ！ 結末はもう知ってるのだ！")
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは布団の中で、\nこっそり『走れメロス』を開いたのだ。")
        await runner.narrate("……結末は知っているのに、\n続きが気になって、眠れなかったのだ。")
        story.set(.chapter1Cleared)
        await runner.chapterTitle("第1章 おわり", "続きが気になるのだ")
        await runner.narrate("つぎのお話「書き込みは、その人の足あとなのだ」は、\nまた夜になったら始まるのだ。")
        leave()
    }
}
