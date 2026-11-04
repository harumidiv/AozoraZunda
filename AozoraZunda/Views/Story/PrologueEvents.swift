import Foundation

/// 序章「字を見ると眠いのだ」のイベント。
/// 雨の夜に図書室へ迷い込み、おフミさんと出会い、迷子の子に絵本を読んで成仏させ、しおりを拾う
struct PrologueEvents {
    let runner: StoryRunner
    let story: StoryStore
    let scene: NightLibraryScene
    /// 部屋に帰る
    let leave: () -> Void

    static let pictureBook = PictureBook(title: "ほしのこ ポロン", pages: [
        PictureBookPage(imageName: "sprite_book_sky", text: "よるの そらに、ちいさな ほしのこ ポロンが いました。"),
        PictureBookPage(imageName: "sprite_book_fall", text: "ある よる、ポロンは すべって、おかの うえに おちて しまいました。\n「おうちは どこ？」\nポロンは えーんと なきました。"),
        PictureBookPage(imageName: "sprite_book_song", text: "すると、ふくろうの おじさんが うたいました。\n「ほうほう、うたの きこえる ほうへ おいき」\nポロンは ふわりと のぼって いきました。"),
        PictureBookPage(imageName: "sprite_book_home", text: "そらの うえで、なかまの ほしたちが まっていました。\n「おかえり、ポロン」\n「ただいま！」"),
        PictureBookPage(imageName: "sprite_book_sky", text: "ポロンは きょうも、みんなと いっしょに きらきら ひかって います。\n\nおしまい"),
    ])

    /// 画面に出しておく「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.prologueCleared) {
            return "夜の図書室なのだ。つぎのお話は、まだ準備中なのだ"
        } else if story.has(.prologueFoundBookmark) {
            return "拾ったしおりを、右奥の「すみの棚」に挟むのだ"
        } else if story.has(.prologueChildPassed) {
            return "左下の床で、何かが光っているのだ"
        } else if story.has(.pictureBook) {
            return "まいごの子に、あおい えほん を読んであげるのだ"
        } else if story.has(.prologueChildAsked) {
            return "あおい えほん をさがすのだ。絵本の棚はどこなのだ？"
        } else if story.has(.prologueMetFumi) {
            return "左下で泣いている、まいごの子の話を聞くのだ"
        }
        return "雨の夜の図書館なのだ…"
    }

    // MARK: - 図書室に入ったとき

    func arrive() async {
        if !story.has(.prologueMetFumi) {
            await opening()
        } else if !story.has(.prologueCleared) {
            await runner.say(.fumi, "おかえりなさい、ずんだもんちゃん")
            await runner.say(.zunda, "か、帰ってきたわけじゃないのだ。雨宿りなのだ")
        }
    }

    private func opening() async {
        await runner.narrate("その夜は、ひどい雨だったのだ。")
        await runner.narrate("雨宿りのつもりで飛び込んだのは、\n見たことのない図書館だったのだ。")
        await runner.chapterTitle("序章", "字を見ると眠いのだ")
        await runner.blackOut(false, duration: 1.2)

        await runner.say(.zunda, "……真っ暗なのだ。誰もいないのだ？")
        await runner.say(.zunda, "本がいっぱいなのだ……。見ているだけで眠くなってきたのだ")
        await scene.appearFumi()
        await runner.say(.unknown, "あらあら。こんな夜更けにお客さんなんて、何十年ぶりかしら")
        await runner.say(.zunda, "ひゃっ！？ だ、誰なのだ！？ 透けてるのだ！")
        await runner.say(.unknown, "わたしはフミ。むかし、ここで司書をしていたの。今は見てのとおり、幽霊ね")
        await runner.say(.fumi, "おフミさん、って呼んでちょうだい。……あら、あなた、ずんだ餅みたいな色ね。おいしそう")
        await runner.say(.zunda, "食べ物じゃないのだ！ ずんだもんなのだ！")
        await runner.say(.fumi, "ここはね、夜だけ開く図書館なの。読みかけの本に心残りがあって、成仏できない子たちが集まってくるのよ")
        await runner.say(.fumi, "その子たちの願いを叶えてあげるのが、夜の司書のお仕事。……ちょうど人手が足りなかったのよねえ")
        let answer = await runner.choose(.fumi, "ずんだもんちゃん、見習いになってくれる？", ["……いやなのだ", "ことわるのだ"])
        if answer == 0 {
            await runner.say(.zunda, "本は字ばっかりで、見ると眠くなるのだ。いやなのだ")
        } else {
            await runner.say(.zunda, "ずんだもんは本が大っきらいなのだ。ことわるのだ")
        }
        await runner.say(.fumi, "まあ！ やってくれるのね、うれしい！")
        await runner.say(.zunda, "話を聞いてないのだ！？")
        await runner.say(.fumi, "雨がやむまででいいから。ね？")
        await runner.say(.zunda, "……雨がやむまでなのだ。早く終わらせて帰るのだ")
        story.set(.prologueMetFumi)
        await runner.say(.fumi, "行きたいところをタップすれば歩けるわ。誰かの前に立ったら「はなす」や「しらべる」ね")
        await runner.say(.fumi, "さっそくだけど、左の奥で迷子の子が泣いているの。話を聞いてあげて")
    }

    // MARK: - おフミさん

    func talkToFumi() async {
        if story.has(.prologueCleared) {
            await runner.say(.fumi, "また来てくれたのね。……今夜は、お客さんは来ないみたい")
            await runner.say(.zunda, "べ、別におフミさんに会いに来たわけじゃないのだ")
            let choice = await runner.choose(.fumi, "ふふ。ゆっくりしていってね", ["またね", "序章を はじめから あそぶ"])
            if choice == 1 {
                story.reset()
                await runner.blackOut(true)
                leave()
            }
        } else if story.has(.prologueFoundBookmark) {
            await runner.say(.fumi, "そのしおりは、右奥の「すみの棚」に挟んでおきましょう。持ち主が見つけられるように")
        } else if story.has(.prologueChildPassed) {
            await runner.say(.fumi, "あら？ あの子がいたあたりで、何か光っているわね")
        } else if story.has(.pictureBook) {
            await runner.say(.fumi, "見つけたのね。あの子のそばで、ゆっくり読んであげて")
        } else if story.has(.prologueChildAsked) {
            await runner.say(.fumi, "絵本なら、右の低い棚よ。あおい表紙をさがしてみて")
            await runner.say(.zunda, "絵本なら字が少ないから、まだマシなのだ……")
        } else {
            await runner.say(.fumi, "左の奥で泣いている子がいるの。話を聞いてあげてね")
            await runner.say(.fumi, "……あ、ずんだ餅、持ってない？")
            await runner.say(.zunda, "持ってないのだ！")
        }
    }

    // MARK: - まいごの子

    func talkToChild() async {
        if story.has(.pictureBook) {
            await runner.say(.zunda, "あおい えほん、これなのだ？")
            await runner.say(.child, "……それ！ ポロンの えほん！")
            let choice = await runner.choose(.child, "よんで、くれるの……？", ["読んであげるのだ", "ちょっと待つのだ"])
            guard choice == 0 else {
                await runner.say(.zunda, "こ、心の準備がいるのだ。ちょっとだけ待つのだ")
                return
            }
            await readToChild()
        } else if story.has(.prologueChildAsked) {
            await runner.say(.child, "あおい えほん……おほしさまの えほん……")
        } else {
            await runner.say(.child, "ぐすっ……ひっく……")
            await runner.say(.zunda, "ど、どうしたのだ？ 迷子なのだ？")
            await runner.say(.child, "あおい えほん、よんでほしいの……。おかあさん、いつも よんでくれたの……")
            await runner.say(.zunda, "ずんだもんが読むのだ……？ 字を見ると眠くなるのだ……")
            await runner.say(.child, "ふぇ……ふぇぇ……")
            await runner.say(.zunda, "わ、わかったのだ！ 泣かないでほしいのだ！ さがしてくるのだ！")
            story.set(.prologueChildAsked)
        }
    }

    private func readToChild() async {
        await runner.say(.zunda, "し、しかたないのだ。読むのだ……")
        await runner.readPictureBook(Self.pictureBook)
        scene.makeChildHappy()
        await runner.say(.child, "……ポロン、おうちに かえれたね")
        await runner.say(.child, "おねえちゃん、ありがとう。……ぼくも、かえれる気がする")
        await runner.say(.zunda, "かえるって、どこに……")
        story.take(.pictureBook)
        story.set(.prologueChildPassed)
        await scene.ascendChild()
        await runner.say(.zunda, "……消えちゃったのだ")
        await runner.say(.fumi, "あの子、ちゃんと帰れたのよ。あなたが最後まで読んであげたから")
        await runner.say(.zunda, "……べ、別に。絵本は本じゃないのだ。だから今のはノーカンなのだ")
        await runner.say(.fumi, "ふふ、はいはい")
        scene.showBookmarkSparkle()
        await runner.say(.zunda, "……ん？ あの子がいたところで、何か光っているのだ")
    }

    // MARK: - しおり

    func pickUpBookmark() async {
        story.give(.bookmark)
        story.set(.prologueFoundBookmark)
        scene.removeBookmarkSparkle()
        await runner.showItemGet(.bookmark)
        await runner.say(.zunda, "あの子の落とし物なのだ？")
        await runner.say(.fumi, "…………")
        await runner.say(.fumi, "……いいえ。あの子のじゃないわね。どの本のしおりかしら")
        await runner.say(.fumi, "持ち主が見つけられるように、右奥の「すみの棚」に挟んでおきましょうか")
    }

    // MARK: - 本棚

    func examineShelf(_ index: Int) async {
        guard index == NightLibraryInteractable.cornerShelf else {
            let lines = [
                "『走れメロス』……走る話なのだ？ 読まなくても疲れそうなのだ",
                "『吾輩は猫である』……猫がしゃべる本なのだ？ 分厚すぎるのだ",
                "『銀河鉄道の夜』……電車の本なのだ？ 字がびっしりなのだ……",
            ]
            await runner.say(.zunda, lines[index % lines.count])
            await runner.say(.zunda, "字を見ているだけで、まぶたが重くなってきたのだ……")
            return
        }
        if story.has(.prologueBookmarkShelved) {
            await runner.say(.zunda, "すみっこに、あのしおりが挟まっているのだ")
        } else if story.has(.bookmark) {
            let choice = await runner.choose(.zunda, "古い本がぎっしりなのだ。すみっこに、少し隙間があるのだ", ["しおりを挟む", "やめておく"])
            guard choice == 0 else { return }
            story.take(.bookmark)
            story.set(.prologueBookmarkShelved)
            scene.showShelvedBookmark()
            await runner.say(.zunda, "ここに挟んでおくのだ。持ち主、見つかるといいのだ")
            await ending()
        } else {
            await runner.say(.zunda, "古い本がぎっしりなのだ。すみっこに、少し隙間があるのだ")
        }
    }

    func examinePictureBookShelf() async {
        if story.has(.prologueChildAsked) && !story.has(.pictureBook) && !story.has(.prologueChildPassed) {
            await runner.say(.zunda, "あおい表紙……これなのだ！ お星さまが描いてあるのだ")
            story.give(.pictureBook)
            await runner.showItemGet(.pictureBook)
            await runner.say(.zunda, "絵ばっかりで、字が少ないのだ。……これなら読めそうなのだ")
        } else if story.has(.prologueChildPassed) {
            await runner.say(.zunda, "絵本が並んでいるのだ。『ほしのこ ポロン』も、ちゃんと戻しておいたのだ")
        } else {
            await runner.say(.zunda, "絵本が並んでいるのだ。絵が多くて、字が少ないのだ")
        }
    }

    // MARK: - 出入口

    func exit() async {
        if story.has(.prologueCleared) {
            await runner.blackOut(true)
            leave()
            return
        }
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "あら、もう帰っちゃうの？ ……また夜に来てね")
        await runner.blackOut(true)
        leave()
    }

    // MARK: - 序章のおわり

    private func ending() async {
        await runner.say(.fumi, "おつかれさま。今夜のお仕事は、これでおしまいよ")
        await runner.say(.zunda, "やっと終わったのだ……。もう来ないのだ")
        await runner.say(.fumi, "あら、雨はまだやんでないわよ？")
        await runner.say(.zunda, "…………")
        await runner.say(.fumi, "明日の夜も、待ってるわね")
        await runner.say(.zunda, "来ないって言ってるのだ！")
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは夢を見たのだ。\n小さなお星さまが、\n空へのぼっていく夢を。")
        story.set(.prologueCleared)
        await runner.chapterTitle("序章 おわり", "字を見ると眠いのだ")
        await runner.narrate("つぎのお話「続きが気になるのだ」は、\nただいま準備中なのだ。")
        leave()
    }
}
