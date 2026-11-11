import Foundation

/// 第4章「声に出すと、もっと楽しいのだ」のイベント。
/// いつも二人で声に出して読み合っていた食いしん坊の兄弟の幽霊・タイチとジロ。
/// 弟のジロだけが先に消えかけているので、『注文の多い料理店』の本の中で、
/// 扉の札を読み合わせながら山猫軒の奥へ進み、最後は3人で読み合わせをする。
/// 本の中の一節は青空文庫の『注文の多い料理店』（宮沢賢治）から引用している
struct Chapter4Events {
    let runner: StoryRunner
    let story: StoryStore
    let library: NightLibraryScene
    /// 本の中へ入る。作った本の中のマップを返す
    let openBook: () -> YamanekoScene
    /// 本を閉じて図書室に戻る
    let closeBook: () -> Void
    let book: () -> YamanekoScene?
    /// 部屋に帰る
    let leave: () -> Void

    static let source = "『注文の多い料理店』宮沢賢治"

    /// 扉の札（表）。【　】のところを読み合わせで当てる
    private struct DoorOrder {
        let front: String
        let options: [String]
        let answer: Int
        /// 裏側に書いてある注文
        let back: String?
    }

    private static let orders: [DoorOrder] = [
        DoorOrder(
            front: "「どなたもどうかお入りください。決してご【　】はありません」",
            options: ["遠慮", "注文", "料金"], answer: 0,
            back: "「ことに肥ったお方や若いお方は、大歓迎いたします」"
        ),
        DoorOrder(
            front: "「当軒は【　】の多い料理店ですからどうかそこはご承知ください」",
            options: ["お客", "注文", "山猫"], answer: 1,
            back: "「注文はずいぶん多いでしょうがどうか一々こらえて下さい。」"
        ),
        DoorOrder(
            front: "「お客さまがた、ここで【　】をきちんとして、それからはきものの泥を落してください。」",
            options: ["顔", "服", "髪"], answer: 2,
            back: "「鉄砲と弾丸をここへ置いてください。」"
        ),
        DoorOrder(
            front: "「どうか帽子と【　】と靴をおとり下さい。」",
            options: ["外套", "手袋", "眼鏡"], answer: 0,
            back: "「ネクタイピン、カフスボタン、眼鏡、財布、その他金物類、\nことに尖ったものは、みんなここに置いてください」"
        ),
        DoorOrder(
            front: "「壺のなかの【　】を顔や手足にすっかり塗ってください。」",
            options: ["ずんだ", "バター", "クリーム"], answer: 2,
            back: "「クリームをよく塗りましたか、耳にもよく塗りましたか、」"
        ),
        DoorOrder(
            front: "「料理はもうすぐできます。\n十五分とお待たせはいたしません。\nすぐたべられます。\n早くあなたの頭に瓶の中の【　】をよく振りかけてください。」",
            options: ["香水", "お酢", "塩"], answer: 0,
            back: "「いろいろ注文が多くてうるさかったでしょう。お気の毒でした。\nもうこれだけです。どうかからだ中に、壺の中の塩をたくさんよくもみ込んでください。」"
        ),
    ]

    /// 図書室にいるときの「いまやること」
    static func objective(_ story: StoryStore) -> String {
        if story.has(.chapter4Escaped) {
            return "タイチとジロに声をかけるのだ"
        } else if story.has(.orderKey) {
            return "兄弟と一緒に、本の中の山猫軒へ行くのだ"
        } else if story.has(.anpan) {
            return "ミツさんのあんパンを、兄弟にそなえるのだ"
        } else if story.has(.chapter4AskedForFood) {
            return "朝になったら、町のパン屋でおそなえものを用意するのだ（出口から部屋に帰る）"
        } else if story.has(.chapter4Started) {
            return "閲覧机の兄弟に話しかけるのだ"
        }
        return "夜の図書室なのだ"
    }

    /// 本の中にいるときの「いまやること」
    static func bookObjective(_ scene: YamanekoScene) -> String {
        if scene.passedDoorways.contains(5) {
            return "……なんだか、様子がおかしいのだ"
        } else if scene.openedDoors.isEmpty {
            return "山猫軒の玄関の札を、兄弟と読み合わせるのだ"
        }
        return "扉の札を読み合わせて、注文どおりにして奥へ進むのだ"
    }

    // MARK: - 図書室

    func arrive() async {
        if !story.has(.chapter4Started) {
            await opening()
        } else if !story.has(.chapter4Cleared) {
            if story.has(.anpan) {
                await runner.say(.fumi, "おかえりなさい。……あら、あまいにおい。にぎやかな二人が待ってるわよ")
            } else {
                await runner.say(.fumi, "おかえりなさい。にぎやかな二人が待ってるわよ")
            }
        }
    }

    private func opening() async {
        await runner.chapterTitle("第4章", "声に出すと、もっと楽しいのだ")
        await runner.blackOut(false, duration: 1.0)
        await runner.say(.taichi, "腹へったー！ ……あ、来た来た！ おフミさーん、来たよー！")
        await runner.say(.zunda, "な、なんなのだ。閲覧机で大きな声を出したらだめなのだ")
        await runner.say(.fumi, "ふふ。今夜のお客さんは、ちょっとにぎやかなの。……でも、ひとりは、とても静か")
        await runner.say(.zunda, "……となりの子、ほとんど透けて見えないのだ")
        story.set(.chapter4Started)
    }

    func talkToFumi() async {
        if story.has(.chapter4Escaped) {
            await runner.say(.fumi, "ふふ、本の中から笑い声が聞こえてたわよ。……図書館では、お静かにね")
        } else if story.has(.orderKey) {
            await runner.say(.fumi, "声に出して読むとね、字が、ちゃんと耳から入ってくるの。眠くならないわよ")
            await runner.say(.zunda, "……ほんとうなのだ？")
        } else if story.has(.anpan) {
            await runner.say(.fumi, "いいにおい……。わたしにも、ひとくち……いえ、なんでもないわ")
        } else if story.has(.chapter4AskedForFood) {
            await runner.say(.fumi, "おそなえものなら、幽霊も食べられるのよ。昼の町のパン屋さん、知ってる？")
        } else {
            await runner.say(.fumi, "あの兄弟、毎晩ここで、二人で声に出して本を読んでたの。……ほかのお客さんには、ちょっと迷惑だったけど")
        }
    }

    func talkToBrothers() async {
        if story.has(.chapter4Escaped) {
            await farewell()
        } else if story.has(.orderKey) {
            let choice = await runner.choose(.taichi, "山猫軒、もう一回行こうぜ！", ["本の中へ", "まだ"])
            if choice == 0 {
                await enterBook()
            }
        } else if story.has(.anpan) {
            await bringAnpan()
        } else if story.has(.chapter4AskedForFood) {
            await runner.say(.taichi, "腹へったー……。ずんだもん、パン、まだー？")
            await runner.say(.zunda, "朝になったら、パン屋さんに行ってくるのだ")
        } else {
            await runner.say(.taichi, "おれ、タイチ！ こっちは弟のジロ。おれたち、食いしん坊兄弟って呼ばれてたんだ")
            await runner.say(.jiro, "…………にいちゃん……")
            await runner.say(.zunda, "声が、すごく小さいのだ")
            await runner.say(.taichi, "……おれたち、いっつも二人で、声に出して本を読んでたんだ。おれが地の文で、ジロがセリフ")
            await runner.say(.taichi, "でもこのごろ、ジロの声がだんだん聞こえなくなって。姿も薄くなって……先に行っちゃいそうなんだ")
            await runner.say(.taichi, "最後にもういっぺん、二人で『注文の多い料理店』を読み合わせしたい。……でも、おれ一人じゃ、ジロの声が聞こえなくて")
            await runner.say(.fumi, "本の中なら、声もよく通るわ。ずんだもんちゃん、三人で読んでらっしゃい")
            await runner.say(.zunda, "こ、声に出して読むなんて、はずかしいのだ……")
            await runner.say(.taichi, "……でもさ、その前に。腹がへって、おれまで声が出ないんだ")
            await runner.say(.taichi, "むかし、本を読んだ帰りに、町のパン屋であんパンを買って、二人で半分こしてたんだ。あれ食べたら、元気出るのになあ")
            await runner.say(.jiro, "……あんパン……")
            await runner.say(.zunda, "ジロが、ちょっとだけしゃべったのだ")
            await runner.say(.fumi, "おそなえものなら、幽霊も食べられるのよ。昼の町のパン屋さんのものなら、きっと")
            await runner.say(.zunda, "……朝になったら、パン屋さんに行ってくるのだ。ずんだ餅じゃなくていいのだ？")
            await runner.say(.taichi, "あんパン！ ぜったい、あんパン！")
            story.set(.chapter4AskedForFood)
            await runner.blackOut(true, duration: 1.0)
            await runner.narrate("朝になったら、町のパン屋で\n兄弟へのおそなえものを用意するのだ。")
            leave()
        }
    }

    /// 朝にもらったあんパンを、兄弟にそなえる
    private func bringAnpan() async {
        await runner.say(.zunda, "おまたせなのだ。パン屋のミツさんの、あんパンなのだ")
        story.take(.anpan)
        await runner.say(.taichi, "これこれ！ この、まんなかのへこみ！ ……ジロ、半分こな")
        await runner.say(.jiro, "……うん。……おいしい")
        await runner.say(.taichi, "……ジロの声、さっきより聞こえる！")
        await runner.say(.jiro, "にいちゃん、ほっぺに、あんこついてる")
        await runner.say(.zunda, "（ほんとうに、ちょっとだけはっきりしたのだ）")
        await runner.say(.taichi, "よーし、元気出た！ ほら、これ。本にはさまってたんだ。山猫軒の玄関の鍵だって、ジロが言ってた")
        story.give(.orderKey)
        story.set(.chapter4GotKey)
        await runner.showItemGet(.orderKey)
        let choice = await runner.choose(.taichi, "行こうぜ、ずんだもん！", ["本の中へ", "ちょっと待つのだ"])
        if choice == 0 {
            await enterBook()
        }
    }

    // MARK: - 本の中

    private func enterBook() async {
        runner.passageSource = Self.source
        await runner.say(.fumi, "目を閉じて。ページの中へ……")
        await runner.blackOut(true, duration: 1.0)
        _ = openBook()
        await runner.quote("二人の若い紳士が、すっかりイギリスの兵隊のかたちをして、ぴかぴかする鉄砲をかついで、白熊のような犬を二疋つれて、だいぶ山奥の、木の葉のかさかさしたとこを、こんなことを云いながら、あるいておりました。")
        await runner.blackOut(false, duration: 1.0)
        await runner.quote("その時ふとうしろを見ますと、立派な一軒の西洋造りの家がありました。")
        await runner.say(.taichi, "山猫軒だ！ ……うわー、腹へってきた！")
        await runner.say(.zunda, "読む前から、おなかがすいてるのだ……")
        await runner.say(.taichi, "扉の札は、おれとジロで読み合わせるからな。ジロが詰まったら、ずんだもんが助けてやって！")
    }

    func signboard() async {
        await runner.quote("RESTAURANT\n西洋料理店\nWILDCAT HOUSE\n山猫軒")
        await runner.say(.taichi, "ここ、本で読むたびに、ジロと「入っちゃだめー！」って叫んでたんだ")
        await runner.say(.zunda, "入っちゃだめなところに、これから入るのだ……？")
    }

    /// 扉の裏にも札があるか（くぐったときに読む）
    static func hasBackText(_ index: Int) -> Bool {
        orders.indices.contains(index) && orders[index].back != nil
    }

    // MARK: 扉

    func door(_ index: Int) async {
        guard let scene = book() else { return }
        if index == 6 {
            await lastDoor()
            return
        }
        guard !scene.openedDoors.contains(index) else { return }
        if !scene.readDoors.contains(index) {
            guard await readAlong(index) else { return }
        }
        let pending = scene.pendingStations(before: index)
        guard pending.isEmpty else {
            await runner.say(.zunda, "扉が開かないのだ。……注文どおりにしないと、だめみたいなのだ")
            await runner.say(.taichi, hint(for: pending[0]))
            return
        }
        if index == 0 {
            await runner.say(.zunda, "鍵を、こうして……開いたのだ！")
        } else {
            await runner.say(.zunda, "よいしょっ……開いたのだ！")
        }
        scene.openDoor(index)
    }

    /// 札を兄弟と読み合わせる。ジロが詰まった言葉を、ずんだもんが選ぶ
    private func readAlong(_ index: Int) async -> Bool {
        guard let scene = book() else { return false }
        let order = Self.orders[index]
        await runner.say(.taichi, index == 0 ? "せーの！" : ["つぎ、いくぞ！", "ジロ、読めるか？", "せーの！"][index % 3])
        await runner.say(.jiro, "……「" + leadIn(order.front) + "……」")
        await runner.say(.jiro, "………………")
        let choice = await runner.fillInBlank(order.front, order.options)
        guard choice == order.answer else {
            await runner.say(.taichi, wrongLine(order.options[choice]))
            await runner.say(.zunda, "うう、もう一回読むのだ")
            return false
        }
        scene.markRead(index)
        await runner.quote(order.front.replacingOccurrences(of: "【　】", with: order.options[order.answer]))
        let reactions: [(StorySpeaker, String)] = [
            (.taichi, "「決してご遠慮はありません」……ただで食べさせてくれるんだぜ、きっと！"),
            (.jiro, "……注文の多い料理店。……にいちゃん、ここ、はやってるんだね"),
            (.taichi, "作法の厳しい家だ。きっとよっぽど偉い人が来るんだ！ ……って、本の紳士も言ってたな"),
            (.jiro, "帽子と、外套と、靴。……ずんだもんちゃん、靴、はいてる？"),
            (.taichi, "クリームだって！ 塗るより食べたい！"),
            (.jiro, "十五分とお待たせはいたしません、だって。……にいちゃん、もうすぐごはんだよ"),
        ]
        let (speaker, line) = reactions[index]
        await runner.say(speaker, line)
        if index == 2 {
            await runner.say(.taichi, "……あれ？ 今のジロの声、ちゃんと聞こえた！")
        }
        return true
    }

    /// 札の最初の言葉だけ（ジロが読みかけて詰まる）
    private func leadIn(_ front: String) -> String {
        let body = front.trimmingCharacters(in: CharacterSet(charactersIn: "「」"))
        return String(body.prefix(8))
    }

    private func wrongLine(_ word: String) -> String {
        switch word {
        case "ずんだ": "ずんだを塗るのは、ずんだもんだけだって！"
        case "塩": "塩はまだ早いって！ ……まだ、だよな？"
        case "お酢": "それ、あとで分かるやつ！ ネタバレ禁止！"
        case "山猫": "それ言っちゃったら、紳士たち入らないって！"
        default: "ちがうちがう！ そんなこと書いてないって！"
        }
    }

    private func hint(for station: YamanekoStation) -> String {
        switch station {
        case .mirror: "鏡とブラシが置いてあるだろ？ 髪をきちんとして、泥を落とすんだ"
        case .stand: "黒い台に、鉄砲を置けって書いてあったよな"
        case .hooks: "帽子と外套と靴だよ。釘にかけるんだ"
        case .safe: "金物は金庫に入れろってさ"
        case .cream: "壺のクリームを塗るんだって！"
        case .creamSmall: "耳にも塗りましたか、だってさ。ちいさな壺があるぞ"
        case .perfume: "香水をふりかけるんだ。金ピカの瓶！"
        case .salt: "……塩？"
        }
    }

    /// 扉を抜けた先で、裏側の注文を読む
    func doorway(_ index: Int) async {
        guard let scene = book(), scene.passDoorway(index), let back = Self.orders[index].back else { return }
        await runner.say(.taichi, "裏にも書いてある！")
        await runner.quote(back)
        switch index {
        case 0:
            await runner.say(.taichi, "大歓迎だって！ おれたち両方兼ねてる！")
            await runner.say(.jiro, "……ぼくらは両方兼ねてるから。……ふふ")
            await runner.say(.zunda, "笑ったのだ。ジロ、今、笑ったのだ")
        case 1:
            await runner.say(.jiro, "……一々、こらえて下さい。……にいちゃん、がまんだよ")
            await runner.say(.taichi, "おなかがすくのは、がまんできないけどな！")
        case 2:
            await runner.say(.zunda, "鉄砲なんて持ってないのだ……")
        case 3:
            await runner.say(.taichi, "ジロ、その眼鏡、入れとけよ。ジロのやつ、本を読むときだけ眼鏡かけるんだ")
        case 4:
            await runner.say(.zunda, "耳……。ずんだもんの耳、どこまで塗ればいいのだ……？")
        case 5:
            scene.lockBehind(5)
            await runner.say(.taichi, "……塩？")
            await runner.say(.jiro, "……にいちゃん。うしろの戸、もう開かないよ")
            await runner.say(.zunda, "ひっ……！ ほ、ほんとうなのだ。一分も動かないのだ！")
        default:
            break
        }
    }

    // MARK: 注文の品

    func station(_ station: YamanekoStation) async {
        guard let scene = book() else { return }
        if scene.doneStations.contains(station) && station != .salt {
            await runner.say(.zunda, "ここの注文は、もうすませたのだ")
            return
        }
        switch station {
        case .mirror:
            await runner.say(.zunda, "髪をきちんとして……頭の枝豆も、ぴかぴかにみがくのだ")
            await runner.quote("ブラシを板の上に置くや否や、そいつがぼうっとかすんで無くなって、風がどうっと室の中に入ってきました。")
            await runner.say(.taichi, "ブラシ、消えた！ 本のとおりだ！")
        case .stand:
            await runner.say(.zunda, "鉄砲はないから……かわりに、ずんだ餅を置いておくのだ")
            await runner.say(.taichi, "置くなよ！ 食べたかったのに！")
        case .hooks:
            await runner.say(.zunda, "ずんだもん、帽子も外套も靴もないのだ……")
            await runner.say(.taichi, "じゃ、おれたちのをかけとこう。ほら、ジロのマフラーも")
            await runner.say(.jiro, "……うん")
        case .safe:
            await runner.say(.taichi, "ジロの眼鏡、入れたぞ。ぱちんと錠をかけて……っと")
            await runner.say(.jiro, "……にいちゃん、眼鏡がないと、字がよく見えないよ")
            await runner.say(.taichi, "大丈夫、おれが読んでやる。……いつもみたいに")
        case .cream:
            await runner.quote("それでもまだ残っていましたから、それは二人ともめいめいこっそり顔へ塗るふりをしながら喰べました。")
            await runner.say(.taichi, "……もぐもぐ")
            await runner.say(.jiro, "……もぐもぐ")
            await runner.say(.zunda, "食べてるのだ！ 本の紳士と、おんなじことしてるのだ！")
        case .creamSmall:
            await runner.say(.zunda, "耳にも、ぬりぬり……。ずんだもんの耳は、どこなのだ……？")
            await runner.say(.taichi, "ここの主人はじつに用意周到だね！ ……って、本のセリフ！")
        case .perfume:
            await runner.say(.zunda, "ぱちゃぱちゃ……。……すっぱいのだ")
            await runner.quote("ところがその香水は、どうも酢のような匂がするのでした。")
            await runner.say(.taichi, "下女が風邪でも引いてまちがえて入れたんだ！")
        case .salt:
            await saltPot()
            return
        }
        scene.complete(station)
    }

    /// 塩壺の前で、兄弟と一緒にやっと気づく
    private func saltPot() async {
        guard let scene = book() else { return }
        guard !scene.doneStations.contains(.salt) else {
            await runner.say(.zunda, "塩は、ぜったいにもみ込まないのだ！")
            return
        }
        scene.complete(.salt)
        await runner.say(.taichi, "……どうもおかしいぜ")
        await runner.say(.jiro, "……ぼくもおかしいとおもう")
        await runner.say(.zunda, "沢山の注文というのは、向うがこっちへ注文してるのだ……！")
        await runner.say(.taichi, "西洋料理を、来た人にたべさせるんじゃなくて、来た人を西洋料理にして……")
        await runner.say(.zunda, "た、た、食べられちゃうのだ！！")
        scene.showEyes()
        await runner.quote("おまけにかぎ穴からはきょろきょろ二つの青い眼玉がこっちをのぞいています。")
        await runner.say(.taichi, "……ここからが、いちばんおもしろいとこなんだ")
        await runner.say(.taichi, "いつも、おれが紳士で、ジロが山猫の子分の声をやってた。……でも、今日は")
        await runner.say(.jiro, "……三人で、やろうよ。ずんだもんちゃんも、子分の役")
        await runner.say(.zunda, "ず、ずんだもんが山猫の子分なのだ！？")
    }

    // MARK: いちばん奥の扉（三人の読み合わせ）

    private func lastDoor() async {
        guard let scene = book() else { return }
        guard scene.doneStations.contains(.salt) else {
            await runner.quote("「いや、わざわざご苦労です。\n大へん結構にできました。\nさあさあおなかにおはいりください。」")
            await runner.say(.zunda, "……な、なんだか、いやな予感がするのだ。塩壺のほうを見てみるのだ")
            return
        }
        guard !story.has(.chapter4Escaped) else { return }
        scene.markRead(6)
        await runner.say(.taichi, "よーし、読み合わせ、はじめるぞ！ おれは紳士の役！ ジロとずんだもんは、扉の向こうの子分の役な！")
        await runner.quote("「いや、わざわざご苦労です。\n大へん結構にできました。\nさあさあおなかにおはいりください。」")
        await runner.say(.taichi, "「うわあ。」がたがたがたがた。")
        await runner.say(.jiro, "「うわあ。」がたがたがたがた。")
        await runner.narrate("扉の向こうの声は、ずんだもんの番なのだ。")
        await performLine(
            prompt: "（扉の向こうで、子分がこそこそ話すのだ）",
            options: [
                "「だめだよ。もう気がついたよ。塩をもみこまないようだよ。」",
                "「わん、わん、ぐゎあ。」",
                "「どなたもどうかお入りください。」",
            ],
            answer: 0
        )
        await runner.say(.taichi, "（うまい！ そのつぎ、ジロ！）")
        await runner.say(.jiro, "「あたりまえさ。親分の書きようがまずいんだ。」")
        await runner.say(.taichi, "（……ジロの声、はっきり聞こえる！）")
        await performLine(
            prompt: "（お客さんを呼ぶのだ！）",
            options: [
                "「ずんだ餅もありますよ。はやくいらっしゃい。」",
                "「へい、いらっしゃい、いらっしゃい。それともサラドはお嫌いですか。そんならこれから火を起してフライにしてあげましょうか。」",
                "「もうおなかいっぱいです。おかえりください。」",
            ],
            answer: 1
        )
        await runner.say(.taichi, "「うわあ。」")
        await runner.say(.jiro, "「うわあ。」")
        await runner.narrate("二人は泣いて泣いて泣いて泣いて泣きました。")
        await runner.say(.zunda, "（このあとは……たしか……）")
        await performLine(
            prompt: "（このとき、うしろから……！）",
            options: [
                "「にゃあお、くゎあ、ごろごろ。」",
                "「旦那あ、旦那あ。」",
                "「わん、わん、ぐゎあ。」",
            ],
            answer: 2
        )
        await scene.dogsBurstIn()
        await runner.quote("あの白熊のような犬が二疋、扉をつきやぶって室の中に飛び込んできました。鍵穴の眼玉はたちまちなくなり……")
        await runner.quote("「にゃあお、くゎあ、ごろごろ。」という声がして、それからがさがさ鳴りました。\n\n室はけむりのように消え、二人は寒さにぶるぶるふるえて、草の中に立っていました。")
        await scene.vanishRestaurant()
        story.set(.chapter4Escaped)
        await runner.say(.taichi, "……ぷっ")
        await runner.say(.jiro, "……ふふっ")
        await scene.brothersLaugh()
        await runner.say(.taichi, "あはははは！ ずんだもん、顔！ クリームでぐしゃぐしゃ！ 紙くずみたい！")
        await runner.say(.jiro, "あはは！ にいちゃんもだよ！ 「わん、わん、ぐゎあ」って、ずんだもんちゃん、本気だった！")
        await runner.say(.zunda, "わ、笑うななのだ！ ……ぷふっ。あはははは！")
        await runner.say(.taichi, "……ジロ。声、ちゃんと聞こえる")
        await runner.say(.jiro, "うん。ぼくにも、にいちゃんの声、聞こえるよ")
        await runner.blackOut(true, duration: 1.0)
        closeBook()
        runner.passageSource = ""
        await runner.blackOut(false, duration: 1.0)
        await farewell()
    }

    /// 3人の読み合わせで、ずんだもんの番のセリフを選ぶ（正しいセリフを選ぶまでやり直す）
    private func performLine(prompt: String, options: [String], answer: Int) async {
        while true {
            let choice = await runner.choose(.zunda, prompt, ["\(options[0].prefix(14))…", "\(options[1].prefix(14))…", "\(options[2].prefix(14))…"])
            if choice == answer {
                await runner.say(.wildcat, options[answer])
                return
            }
            await runner.say(.wildcat, options[choice])
            await runner.say(.taichi, "あはは、ちがうって！ ずんだもん、ちゃんと本読んだ？")
            await runner.say(.zunda, "うう……もう一回なのだ")
        }
    }

    // MARK: - 図書室にもどって

    private func farewell() async {
        library.makeBrothersClear()
        await runner.say(.taichi, "あー、笑った！ 腹へってたの、忘れてた")
        await runner.say(.jiro, "にいちゃん。ぼく、もう、先に行かなくていいみたい")
        await runner.say(.taichi, "……うん。一緒に行こう。いつもみたいに、二人で")
        await runner.say(.taichi, "ずんだもん、ありがとな！ 子分の役、最高だった！")
        await runner.say(.jiro, "ずんだもんちゃんの「わん、わん、ぐゎあ」、ずっと忘れないよ")
        await runner.say(.zunda, "そ、それは忘れてほしいのだ……！")
        story.set(.chapter4BrothersPassed)
        await library.ascendBrothers()
        await runner.say(.zunda, "……笑いながら、行っちゃったのだ")
        await runner.say(.fumi, "本はね、一人で読むだけじゃないの。誰かと声に出したら、笑い声まで一緒に覚えていられるのよ")
        await runner.say(.zunda, "……声に出して読むの、ちょっとだけ、楽しかったのだ")
        await runner.say(.fumi, "あら！ 今の、もう一回言って？")
        await runner.say(.zunda, "い、言ってないのだ！ 空耳なのだ！")
        await runner.say(.fumi, "ふふふ。……ああ、笑ったらおなかすいちゃった。ずんだ餅、ない？")
        await runner.say(.zunda, "山猫軒の黒い台に置いてきたのだ")
        await runner.blackOut(true, duration: 1.2)
        await runner.narrate("その夜、ずんだもんは、\n部屋でこっそり声に出して本を読んでみたのだ。")
        await runner.narrate("……ひとりだと、ちょっとさみしかったのだ。")
        story.set(.chapter4Cleared)
        await runner.chapterTitle("第4章 おわり", "声に出すと、もっと楽しいのだ")
        await runner.narrate("つぎのお話「消えた本」は、\nまた夜になったら始まるのだ。")
        leave()
    }

    func exit() async {
        let choice = await runner.choose(.zunda, "部屋に帰るのだ？", ["かえる", "もどる"])
        guard choice == 0 else { return }
        await runner.say(.taichi, "えー、もう帰るのかよー！ ……また来いよな！")
        await runner.blackOut(true)
        leave()
    }
}
