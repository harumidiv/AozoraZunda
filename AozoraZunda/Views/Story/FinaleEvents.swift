import Foundation

/// 終章「最後まで読むのだ」とエピローグ「今日はどれから読むのだ」のイベント。
/// おフミさんが待ちつづけていた本『手袋を買いに』と、それを借りたまま本の中に閉じこもっていた少女・はる。
/// ずんだもんは本の中の雪の町ではるを見つけ、図書室で、おフミさんとはるの前で最後まで読み聞かせる。
/// 本の中の一節は青空文庫の『手袋を買いに』（新美南吉）から引用している
struct FinaleEvents {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 本の中へ入る。作った本の中のマップを返す
    let openBook: () -> TebukuroScene
    /// 本を閉じて図書室に戻る
    let closeBook: () -> Void
    let book: () -> TebukuroScene?
    /// 部屋に帰る
    let leave: () -> Void

    static let source = "『手袋を買いに』新美南吉"

    /// 読み聞かせ（前半）。子狐が手袋を買うところまで
    static let readingFirst = PictureBook(title: "手袋を買いに", pages: [
        PictureBookPage(imageName: "sprite_tebukuro_morning", text: "寒い冬が北方から、狐の親子の棲んでいる森へもやって来ました。\n子供の狐は遊びに行きました。真綿のように柔かい雪の上を駈け廻ると、雪の粉が、しぶきのように飛び散って小さい虹がすっと映るのでした。"),
        PictureBookPage(imageName: nil, text: "「お母ちゃん、お手々が冷たい、お手々がちんちんする」\n……かあいい坊やの手に霜焼ができてはかわいそうだから、夜になったら、町まで行って、坊やのお手々にあうような毛糸の手袋を買ってやろうと思いました。"),
        PictureBookPage(imageName: "sprite_tebukuro_walk", text: "やがて、行手にぽっつりあかりが一つ見え始めました。\n「母ちゃん、お星さまは、あんな低いところにも落ちてるのねえ」\n「あれはお星さまじゃないのよ」……「あれは町の灯なんだよ」"),
        PictureBookPage(imageName: nil, text: "「坊やお手々を片方お出し」とお母さん狐がいいました。その手を、母さん狐はしばらく握っている間に、可愛いい人間の子供の手にしてしまいました。"),
        PictureBookPage(imageName: "sprite_tebukuro_town", text: "子供の狐は、町の灯を目あてに、雪あかりの野原をよちよちやって行きました。始めのうちは一つきりだった灯が二つになり三つになり、はては十にもふえました。"),
        PictureBookPage(imageName: "sprite_tebukuro_hatshop", text: "子狐はその光がまばゆかったので、めんくらって、まちがった方の手を、――お母さまが出しちゃいけないと言ってよく聞かせた方の手をすきまからさしこんでしまいました。\n「このお手々にちょうどいい手袋下さい」"),
        PictureBookPage(imageName: nil, text: "……これは木の葉じゃない、ほんとのお金だと思いましたので、棚から子供用の毛糸の手袋をとり出して来て子狐の手に持たせてやりました。"),
    ])

    /// 読み聞かせ（中ほど）。窓の唄声のところ
    static let readingMiddle = PictureBook(title: "手袋を買いに", pages: [
        PictureBookPage(imageName: "sprite_tebukuro_lullaby", text: "ある窓の下を通りかかると、人間の声がしていました。何というやさしい、何という美しい、何と言うおっとりした声なんでしょう。\n「ねむれ　ねむれ\n母の胸に、\nねむれ　ねむれ\n母の手に――」"),
        PictureBookPage(imageName: nil, text: "「母ちゃん、こんな寒い夜は、森の子狐は寒い寒いって啼いてるでしょうね」\nそれをきくと子狐は急にお母さんが恋しくなって、"),
    ])

    /// 読み聞かせ（おしまいまで）
    static let readingLast = PictureBook(title: "手袋を買いに", pages: [
        PictureBookPage(imageName: nil, text: "……それをきくと子狐は急にお母さんが恋しくなって、お母さん狐の待っている方へ跳んで行きました。"),
        PictureBookPage(imageName: "sprite_tebukuro_moon", text: "二匹の狐は森の方へ帰って行きました。月が出たので、狐の毛なみが銀色に光り、その足あとには、コバルトの影がたまりました。"),
        PictureBookPage(imageName: nil, text: "「母ちゃん、人間ってちっとも恐かないや」\n……お母さん狐は、\n「まあ！」とあきれましたが、「ほんとうに人間はいいものかしら。ほんとうに人間はいいものかしら」とつぶやきました。"),
    ])

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.epilogueCleared) {
            return "夜の図書室なのだ。夜間司書のずんだもんの、お仕事なのだ"
        } else if story.has(.finaleCleared) {
            return "朝の図書室なのだ。……本棚の前へ行ってみるのだ"
        } else if story.has(.finaleFoundHaru) {
            return "はるに声をかけて、本を読んであげるのだ"
        } else if story.has(.finaleStarted) {
            return "押し花のしおりで、はるのいる本の中へ行くのだ（おフミさんに話しかける）"
        }
        return "夜の図書室なのだ"
    }

    /// 本の中にいるときの「いまやること」
    static func bookObjective(_ story: StoryStore) -> String {
        if story.has(.finaleGotMittens) {
            return "窓の下の女の子に、手袋を持っていくのだ"
        } else if story.has(.finaleGotCoins) {
            return "町で、黒い大きなシルクハットの看板をさがすのだ"
        }
        return "雪の森なのだ。小さな足あとを追いかけて、町のほうへ行くのだ"
    }

    // MARK: - 図書室

    func arrive() async {
        if !story.has(.finaleStarted) {
            await opening()
        } else if story.has(.finaleCleared) && !story.has(.epilogueCleared) {
            await morning()
        } else if story.has(.finaleFoundHaru) && !story.has(.finaleCleared) {
            await runner.say(.fumi, "おかえりなさい。……はるちゃんも、待ってるわ")
        } else if !story.has(.finaleCleared) {
            await runner.say(.fumi, "おかえりなさい。……はるちゃんのこと、お願いね")
        }
    }

    private func opening() async {
        await runner.chapterTitle("終章", "最後まで読むのだ")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.fumi, "いらっしゃい、ずんだもんちゃん。……約束どおり、話すわね")
        await runner.say(.fumi, "わたしはね、生きていたころ、小さな図書室の司書だったの")
        await runner.blackOut(true, duration: 1.0)
        await runner.narrate("むかし、小さな図書室に、\n体の弱い女の子が通っていたのだ。")
        await runner.narrate("その子は、雪の日も外で遊べなくて、\nいつも窓ぎわで本を読んでいたのだ。")
        await runner.narrate("「元気になったら返してね。\n感想も聞かせてね」")
        await runner.narrate("女の子は、押し花のしおりをはさんだ本を\nだいじにかかえて、帰っていったのだ。")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.fumi, "はるちゃんが最後に借りていったのが『手袋を買いに』。雪の町に、子狐がひとりで手袋を買いに行くお話")
        await runner.say(.fumi, "……でも、あの子は、来なかった。本も、返ってこなかった")
        await runner.say(.fumi, "誰も悪くないの。ただ、約束の日が、来なかっただけ")
        await runner.say(.fumi, "「わたしの願いは、まだいいの」って言ってたのはね。……ずっと、ここで待ってたからなの")
        await runner.say(.zunda, "…………")
        await runner.say(.zunda, "おフミさん。……このしおり。最初の夜に拾った、押し花のしおりなのだ")
        await runner.say(.fumi, "……ええ。わたしが、はるちゃんにあげたしおり")
        await runner.say(.fumi, "しおりはね、読みかけのページを覚えてるの。あの子はきっと、本の中で……まだ、読みかけのまま")
        await runner.say(.zunda, "ずんだもんが、迎えに行ってくるのだ")
        await runner.say(.fumi, "……わたしは、ここで待ってる。あの子が帰ってくる場所は、ここだから")
        story.set(.finaleStarted)
        let choice = await runner.choose(.fumi, "……お願いできる？", ["本の中へ", "ちょっと待つのだ"])
        if choice == 0 {
            await enterBook()
        }
    }

    func talkToFumi() async {
        if story.has(.finaleFoundHaru) {
            await runner.say(.fumi, "はるちゃんに、読んであげて。……わたしも、一緒に聞くわ")
        } else {
            let choice = await runner.choose(.fumi, "しおりのページから、本の中へ行ける？", ["本の中へ", "まだ"])
            if choice == 0 {
                await enterBook()
            }
        }
    }

    func cornerShelf() async {
        if story.has(.finaleCleared) {
            await epilogueEnding()
        } else {
            await runner.say(.zunda, "一冊ぶんの隙間なのだ。……ここに、本を返してもらうのだ")
        }
    }

    func otherShelf() async {
        if story.has(.finaleCleared) {
            await epilogueEnding()
        } else {
            await runner.say(.zunda, "今は、はるのことが先なのだ")
        }
    }

    func talkToHaru() async {
        guard !story.has(.finaleReadToEnd) else { return }
        await runner.say(.haru, "……ずんだもんちゃん。読んで、くれる？")
        await readAloud()
    }

    // MARK: - 本の中

    private func enterBook() async {
        runner.passageSource = Self.source
        await runner.say(.fumi, "しおりのページへ……。目を閉じて")
        await runner.blackOut(true, duration: 1.0)
        _ = openBook()
        await runner.quote("暗い暗い夜が風呂敷のような影をひろげて野原や森を包みにやって来ましたが、雪はあまり白いので、包んでも包んでも白く浮びあがっていました。")
        await runner.blackOut(false, duration: 1.0)
        if story.has(.finaleGotMittens) {
            await runner.say(.zunda, "手袋は持ってるのだ。窓の下の女の子のところへ行くのだ")
        } else {
            await runner.say(.zunda, "さ、さむいのだ……！ 一面、雪なのだ")
            await runner.say(.zunda, "（今夜は、ずんだもんひとりなのだ。……子狐みたいなのだ）")
        }
    }

    func foxes() async {
        guard !story.has(.finaleGotCoins) else {
            await runner.say(.foxChild, "母ちゃん、お星さまは、あんな低いところにも落ちてるのねえ")
            await runner.say(.foxMother, "あれはお星さまじゃないのよ。……町の灯なんだよ")
            return
        }
        await runner.say(.foxChild, "母ちゃん、だれか来たよ。緑色の子")
        await runner.say(.foxMother, "……人間の子ね。こんな夜に、どうしたの")
        await runner.say(.zunda, "女の子をさがしてるのだ。本をかかえた、三つ編みの子なのだ")
        await runner.say(.foxMother, "さっき、小さな足あとが町のほうへ。……手がまっかだったわ。手袋もしないで")
        await runner.say(.foxMother, "これをお持ちなさい。坊やの手袋を買うぶんの、のこり")
        story.give(.coins)
        story.set(.finaleGotCoins)
        await runner.showItemGet(.coins)
        await runner.quote("「いいかい坊や、町へ行ったらね、たくさん人間の家があるからね、まず表に円いシャッポの看板のかかっている家を探すんだよ。それが見つかったらね、トントンと戸を叩いて、今晩はって言うんだよ」")
        await runner.say(.zunda, "円いシャッポ……帽子の看板なのだ。ありがとうなのだ！")
    }

    func footprints(_ index: Int) async {
        let lines = [
            "小さな足あとなのだ。……狐じゃない、人間の子の足あとなのだ",
            "足あとが、町の灯のほうへつづいてるのだ。ひとつだった灯が、ふたつ、みっつ……",
            "足あとが、ちょっとよろけてるのだ。……さむかったのだ",
        ]
        await runner.say(.zunda, lines[index % lines.count])
    }

    func glimpse() async {
        guard let scene = book() else { return }
        await scene.glimpseShadow()
        await runner.say(.zunda, "今の……！ 本をかかえた影なのだ！ 町のほうへ行っちゃったのだ")
    }

    func sign(_ index: Int) async {
        if index == 0 {
            await runner.say(.zunda, "自転車の看板なのだ。……帽子じゃないのだ")
        } else {
            await runner.say(.zunda, "眼鏡の看板なのだ。古い壁のようにはげてるのだ。……帽子じゃないのだ")
        }
    }

    func hatShop() async {
        guard let scene = book() else { return }
        if story.has(.finaleGotMittens) {
            await runner.say(.zunda, "戸は、もう閉まってるのだ。……帽子屋さん、ありがとうなのだ")
            return
        }
        await runner.say(.zunda, "黒い大きなシルクハットの看板……。ここなのだ！")
        await runner.say(.zunda, "トントン。……今晩は、なのだ")
        scene.openHatShopDoor(true)
        await runner.quote("すると、中では何かことこと音がしていましたがやがて、戸が一寸ほどゴロリとあいて、光の帯が道の白い雪の上に長く伸びました。")
        guard story.has(.coins) else {
            await runner.say(.hatter, "……手袋かい？ 先にお金を下さい")
            await runner.say(.zunda, "お、お金……持ってないのだ……")
            scene.openHatShopDoor(false)
            await runner.say(.zunda, "（森の狐の親子に、話を聞いてみるのだ）")
            return
        }
        let choice = await runner.choose(.zunda, "すきまから、手を……", ["右手を出す", "左手を出す"])
        await runner.say(.zunda, choice == 0 ? "（右手なのだ。……どっちも、ずんだもんの手なのだ）" : "（左手なのだ。……どっちも、ずんだもんの手なのだ）")
        await runner.say(.hatter, "……おや。ずいぶん、緑色の手だね")
        await runner.say(.zunda, "女の子の手に、ちょうどいい手袋、下さいなのだ")
        await runner.say(.hatter, "先にお金を下さい")
        await runner.quote("帽子屋さんはそれを人差指のさきにのっけて、カチ合せて見ると、チンチンとよい音がしました")
        story.take(.coins)
        await runner.say(.hatter, "ほんとのお金だ。……はい、子供用の毛糸の手袋。あったかいよ")
        story.give(.mittens)
        story.set(.finaleGotMittens)
        await runner.showItemGet(.mittens)
        scene.openHatShopDoor(false)
        await runner.say(.zunda, "帽子屋さん、ちっとも恐くなかったのだ")
    }

    func lullabyWindow() async {
        await runner.quote("「ねむれ　ねむれ\n母の胸に、\nねむれ　ねむれ\n母の手に――」")
        await runner.say(.zunda, "……やさしい声なのだ")
    }

    /// 窓の下にうずくまっていたはる
    func haruInBook() async {
        guard let scene = book() else { return }
        guard story.has(.mittens) else {
            await runner.say(.unknown, "……こないで")
            await runner.say(.unknown, "……さむい。手が、つめたいの")
            await runner.say(.zunda, "手がまっかなのだ……。手袋があれば、あったかいのに……")
            if !story.has(.coins) && !story.has(.finaleGotCoins) {
                await runner.say(.zunda, "（森の洞穴のほうに、狐の親子がいたのだ）")
            }
            return
        }
        await runner.say(.zunda, "これ、はめるのだ。帽子屋さんで買ってきたのだ")
        story.take(.mittens)
        scene.giveMittensToHaru()
        await runner.say(.haru, "…………あったかい")
        await runner.say(.haru, "わたし、はる。……雪の日に、外で遊んだこと、なかったの。いつも窓から見てるだけ")
        await runner.say(.zunda, "はる……！ 貸出カードの、はるなのだ？ おフミさんが、ずっと待ってるのだ")
        await runner.say(.haru, "……知ってる。おフミさん、まだ待ってるんだよね")
        await runner.say(.haru, "この本、ここまで読んだの。子狐が、町に来たところ。……そこから先が、読めないの")
        await runner.say(.zunda, "どうしてなのだ？")
        await runner.say(.haru, "読んだら、お話がおわっちゃう。おわったら、本を返さなきゃ")
        await runner.say(.haru, "……返したら、もう、おフミさんに会いに行く理由が、なくなっちゃう")
        await runner.say(.haru, "だから、ずっとここで、しおりをはさんだまま……")
        await runner.say(.zunda, "…………")
        await runner.say(.zunda, "ずんだもんも、ちょっと分かるのだ。……本を閉じるのって、さよならみたいなのだ")
        await runner.say(.zunda, "でも、おわっても、なくならないのだ。タクも、タマも、サチも、タイチとジロも……ちゃんと、ずんだもんの中に残ってるのだ")
        await runner.say(.zunda, "ずんだもんが、最後まで読むのだ。おフミさんと、はると、三人で聞くのだ")
        await runner.say(.haru, "……ずんだもんちゃん、字を見ると眠くなるんでしょ？")
        await runner.say(.zunda, "な、なんで知ってるのだ！ ……眠くなっても、最後まで読むのだ")
        await runner.say(.haru, "……ふふ。じゃあ、帰ろう。おフミさんのところへ")
        scene.makeHaruHappy()
        story.set(.finaleFoundHaru)
        await runner.blackOut(true, duration: 1.0)
        closeBook()
        runner.passageSource = ""
        library.showHaru()
        await runner.blackOut(false, duration: 1.0)
        await readAloud()
    }

    // MARK: - 図書室にもどって

    /// おフミさんとはるの前で、ずんだもんが最後まで読み聞かせる
    private func readAloud() async {
        await library.walkHaruToFumi()
        await runner.say(.fumi, "……はるちゃん")
        await runner.say(.haru, "……おフミさん。おそくなって、ごめんなさい")
        await runner.say(.fumi, "……いいのよ。いいの")
        await runner.say(.zunda, "それじゃあ……読むのだ。『手袋を買いに』。新美南吉")
        await runner.readPictureBook(Self.readingFirst)
        await runner.say(.haru, "……帽子屋さん、やさしい")
        await runner.say(.zunda, "つ、つぎのページなのだ")
        await runner.readPictureBook(Self.readingMiddle)
        await runner.say(.zunda, "……それをきくと、子狐は……急に、お母さんが……")
        await runner.narrate("声が、つまったのだ。")
        await runner.say(.haru, "……ずんだもんちゃん？")
        await runner.say(.zunda, "な、なんでもないのだ。……字が、にじんで見えるだけなのだ")
        await runner.say(.fumi, "ゆっくりでいいのよ。……ちゃんと、聞いてるから")
        await runner.say(.zunda, "……………")
        await runner.say(.zunda, "……最後まで、読むのだ")
        await runner.readPictureBook(Self.readingLast)
        await runner.say(.zunda, "……おしまい、なのだ")
        story.set(.finaleReadToEnd)
        await impressions()
    }

    /// はるが本を返して、約束の感想を伝える。ずんだもんもカードを渡す
    private func impressions() async {
        await runner.say(.haru, "おフミさん。……本、かえします")
        await runner.say(.fumi, "……はい。たしかに、お返しいただきました")
        await runner.say(.haru, "それから……感想。約束してたから")
        await runner.say(.haru, "子狐が、まちがえてほんとうのお手々を出しちゃったところ、どきどきした。でも、帽子屋さんが手袋をくれて、すごくうれしかった")
        await runner.say(.haru, "窓の唄のところで、お母さんのこと、思いだした")
        await runner.say(.haru, "「ほんとうに人間はいいものかしら」って。……いいものだったよ。おフミさんも、ずんだもんちゃんも")
        await runner.say(.fumi, "…………ありがとう。いちばん、聞きたかった感想だわ")
        library.makeHaruHappy()
        await runner.say(.zunda, "お、おフミさん。……ずんだもんからも、あるのだ")
        await runner.say(.zunda, "机の引き出しにしまってた、カード。……つづき、今なら書けるのだ")
        let endings = [
            "また、いっしょに本を読みたいのだ。",
            "本、ちょっとだけ好きになったのだ。",
            "ずっと待っててくれて、ありがとうなのだ。",
        ]
        let choice = await runner.choose(.zunda, "おフミさんへ。本のことは、まだよくわからないけど、", endings)
        let card = "おフミさんへ。\n本のことは、まだよくわからないけど、\n\(endings[choice])\n　　　　　　　　　　ずんだもん"
        story.setMemo(card, for: Chapter3Events.memoKey)
        await runner.showHandwriting([HandwrittenNote(text: card)])
        await runner.say(.fumi, "…………")
        await runner.say(.fumi, "……ふふ。……うれしい。わたしの願い、ぜんぶ、かなっちゃった")
        await runner.say(.fumi, "ずんだもんちゃん。夜間司書見習いは、今夜でおしまい")
        await runner.say(.zunda, "え……")
        await runner.say(.fumi, "今日からは、夜間司書。……この図書室を、よろしくね")
        await runner.say(.zunda, "ま、待つのだ！ ずんだ餅、まだおそなえしてないのだ！")
        await runner.say(.fumi, "ふふ。……それは、つぎに来る人と一緒に食べて")
        await runner.say(.haru, "ずんだもんちゃん、ありがとう。……つぎの本も、最後まで読んでね")
        story.take(.bookmark)
        story.take(.lendingCard)
        story.set(.finaleFumiPassed)
        await library.ascendFumiAndHaru()
        await runner.say(.zunda, "……おフミさん……")
        await runner.say(.zunda, "……いっちゃったのだ。……最後まで、ずんだ餅の話だったのだ")
        story.set(.finaleCleared)
        await runner.blackOut(true, duration: 1.4)
        await runner.chapterTitle("終章 おわり", "最後まで読むのだ")
        await morning()
    }

    // MARK: - エピローグ

    /// 朝の図書室。ひとり残ったずんだもん
    private func morning() async {
        await runner.blackOut(true, duration: 0.6)
        library.makeMorning()
        await runner.chapterTitle("エピローグ", "今日はどれから読むのだ")
        await runner.blackOut(false, duration: 1.4)
        await runner.say(.zunda, "……朝なのだ。雨、やんだのだ")
        await runner.say(.zunda, "……しずかなのだ。カウンターに、だれもいないのだ")
        await runner.say(.zunda, "おフミさんの声がしないと……図書室って、こんなに広かったのだ")
        await runner.say(.zunda, "………………")
        await runner.say(.zunda, "……よし、なのだ")
    }

    private func epilogueEnding() async {
        await runner.blackOut(true, duration: 0.8)
        await runner.narrate("ずんだもんは、本棚から本を山ほど抜き出して、\n床にどさっと積み上げたのだ。")
        await runner.blackOut(false, duration: 0.8)
        await runner.say(.zunda, "『走れメロス』、『吾輩は猫である』、『銀河鉄道の夜』、『注文の多い料理店』、それから『手袋を買いに』……")
        await runner.say(.zunda, "ぜんぶ、もう一回、最初から読むのだ。……字を見ると、やっぱりちょっと眠いけど")
        await runner.say(.zunda, "今日はどれから読むのだ")
        library.showNewcomer(animated: true)
        await runner.wait(1.4)
        await runner.say(.newcomer, "……あの。ここ、本を読んでもいいところ？")
        await runner.say(.zunda, "…………！")
        await runner.say(.zunda, "い、いらっしゃいなのだ！ 夜間司書の、ずんだもんなのだ！")
        story.set(.epilogueCleared)
        await runner.blackOut(true, duration: 1.4)
        await runner.chapterTitle("おしまい", "あおぞら夜間図書室")
        await runner.narrate("幽霊図鑑に、ずんだもんの読書感想メモが\n追加されたのだ。\n「ずかん」から見られるのだ。")
        leave()
    }

    // MARK: - クリアのあと

    func talkToNewcomer() async {
        await runner.say(.newcomer, "ぼく、読みかけの本があって……どこにあるか、わからなくなっちゃったんだ")
        await runner.say(.zunda, "まかせるのだ。夜間司書のずんだもんが、さがしてあげるのだ")
        let choice = await runner.choose(.newcomer, "……ほんと？ ありがとう", ["またね", "はじめから あそぶ"])
        if choice == 1 {
            let confirm = await runner.choose(.zunda, "ストーリーの進み具合を消して、序章からはじめるのだ？", ["はじめから", "やめておく"])
            guard confirm == 0 else { return }
            story.reset()
            await runner.blackOut(true)
            leave()
        }
    }

    func exit() async {
        if story.has(.finaleCleared) && !story.has(.epilogueCleared) {
            await runner.say(.zunda, "……帰る前に、本棚を見ていくのだ")
            return
        }
        if story.has(.epilogueCleared) {
            await runner.blackOut(true)
            leave()
            return
        }
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.fumi, "おやすみなさい。……また、来てね")
        await runner.blackOut(true)
        leave()
    }
}
