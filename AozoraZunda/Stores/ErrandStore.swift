import Foundation
import Observation

/// 町にいて、読みたい本をさがしている人
enum Townsperson: String, Codable, CaseIterable {
    /// パン屋のおかみさん
    case baker
    /// 男の子
    case boy
    /// 公園のおじいさん
    case grandpa
    /// 学生のお姉さん
    case student

    var name: String {
        switch self {
        case .baker: "パン屋のミツさん"
        case .boy: "ソウタ"
        case .grandpa: "ゲンさん"
        case .student: "ユイさん"
        }
    }

    /// 頼まれごとをぜんぶ届けたあとのひとこと
    var allDoneLine: String {
        switch self {
        case .baker: "ずんだもんちゃんのおかげで、店番の時間が楽しみになったわ。またパンを買いにきてね"
        case .boy: "本ってさ、のりものより遠くに行けるんだな！ また何か教えてよ"
        case .grandpa: "孫がな、今度は自分で図書館に行くと言うとった。ありがとうな"
        case .student: "レポート、いい点だったの。こんどはわたしがおすすめを教えてあげるね"
        }
    }
}

/// 町の人の「こんな本が読みたい」という頼みごと
struct BookWish: Identifiable {
    let id: String
    let person: Townsperson
    /// 頼むときのセリフ（「〇〇な本を探してるんだよなー」）
    let request: [String]
    /// たのまれごとの一覧に出す短い説明
    let summary: String
    /// ヒントをきいたときのずんだもんの考え
    let hint: String
    /// 届けたときのお礼
    let thanks: [String]
    /// ちがう本を渡したとき
    let wrongBook: String
    /// 届ける本の条件
    let matches: (CatalogBook) -> Bool

    /// 題名にどれかの言葉が入っている本
    static func titleContains(_ words: [String]) -> (CatalogBook) -> Bool {
        { book in words.contains { book.title.contains($0) } }
    }

    /// 題名がぴったり同じ本（作家も指定できる）
    static func title(_ title: String, author: String? = nil) -> (CatalogBook) -> Bool {
        { book in book.title == title && (author.map { book.authorName == $0 } ?? true) }
    }

    /// その作家の本ならどれでも
    static func author(_ name: String) -> (CatalogBook) -> Bool {
        { book in book.authorName == name }
    }
}

extension BookWish {
    /// 町の人ごとに、上から順に頼まれる
    static let all: [BookWish] = [
        // パン屋のミツさん
        BookWish(
            id: "baker.cat",
            person: .baker,
            request: [
                "あら、ずんだもんちゃん。いらっしゃい",
                "最近ね、お店の前に野良猫が遊びにくるのよ。それで、猫が出てくるお話を読んでみたくなっちゃって",
                "猫が出てくる本、探してるんだけどねえ……",
            ],
            summary: "猫が出てくるお話",
            hint: "題名に「猫」が入っている本なら、まちがいないのだ。司書さんに題名でさがしてもらうのだ",
            thanks: [
                "まあ、猫のお話！ 表紙をながめてるだけで、なんだか顔がゆるんじゃう",
                "お店がひまな時間に読ませてもらうわね。ありがとう、ずんだもんちゃん",
            ],
            wrongBook: "あら、それも面白そう。でも、いまは猫のお話の気分なのよねえ",
            matches: titleContains(["猫"])
        ),
        BookWish(
            id: "baker.glove",
            person: .baker,
            request: [
                "猫のお話、ぜんぶ読んじゃった。おかげで、店番がちっとも退屈じゃないの",
                "そろそろ寒くなってきたでしょう。手袋が出てくるような、冬のあったかいお話はないかしら",
            ],
            summary: "手袋が出てくる、冬のお話",
            hint: "題名に「手袋」が入っている本をさがすのだ。新美南吉の、きつねの子のお話が有名なのだ",
            thanks: [
                "手袋のお話ね！ ……ふふ、読む前から指先があったかくなってきた気がするわ",
                "お礼に、焼きたてのパンのにおいだけでも、たっぷりかいでいってちょうだい",
            ],
            wrongBook: "うーん、それじゃないのよねえ。手袋が出てくる、冬のお話がいいの",
            matches: titleContains(["手袋"])
        ),

        // ソウタ
        BookWish(
            id: "boy.train",
            person: .boy,
            request: [
                "なあなあ、ずんだもん。おれ、のりものが大好きなんだ",
                "汽車とか電車とかが出てくる本ってないかな。図書館って、むずかしい本ばっかりなんだろ？",
            ],
            summary: "汽車や電車が出てくる本",
            hint: "題名に「汽車」「電車」「鉄道」のどれかが入っている本をさがすのだ。宮沢賢治の、星空を走る汽車のお話もあるのだ",
            thanks: [
                "うおー！ ほんとに汽車の本だ！ 図書館って、こういうのもあるんだな",
                "読んだら感想いうから、また来いよな！",
            ],
            wrongBook: "えー、それ、汽車も電車も出てこなさそう……。のりものの本がいいんだよなー",
            matches: titleContains(["汽車", "電車", "鉄道"])
        ),
        BookWish(
            id: "boy.melos",
            person: .boy,
            request: [
                "汽車の本、おもしろかった！ 本ってけっこうやるじゃん",
                "こんどはさ、友だちとの約束を守るために、ひたすら走るみたいな……かっこいい話が読みたいんだよなー",
            ],
            summary: "友だちとの約束のために走る、かっこいい話",
            hint: "それはきっと、太宰治の『走れメロス』なのだ。「た」の棚にあるのだ",
            thanks: [
                "『走れメロス』！ 題名からもう走ってる！ これだよこれ！",
                "読み終わったら、おれも明日の朝から走ってみる！",
            ],
            wrongBook: "うーん、それ、走ってる感じしないんだよなー。友だちのために走る話がいいの！",
            matches: title("走れメロス", author: "太宰治")
        ),

        // ゲンさん
        BookWish(
            id: "grandpa.kenji",
            person: .grandpa,
            request: [
                "やあ、ずんだもんさん。今日はええ天気じゃのう",
                "こんど孫が遊びにくるんじゃが、寝る前に何か読んでやりたくてな",
                "わしが子どものころ好きだった、宮沢賢治の本がええんじゃが……どれがええか、もう思い出せんでのう",
            ],
            summary: "宮沢賢治の本（どれでも）",
            hint: "宮沢賢治の本なら、どれでもいいみたいなのだ。司書さんに作家でさがしてもらうか、「ま」の棚を見るのだ",
            thanks: [
                "おお、宮沢賢治じゃ。なつかしいのう……表紙を見ただけで、あのころの夏の夜を思い出すわい",
                "孫といっしょに読むのが楽しみじゃ。ありがとうな",
            ],
            wrongBook: "ふむ、ええ本じゃが……宮沢賢治のが読んでやりたいんじゃよ",
            matches: author("宮沢賢治")
        ),
        BookWish(
            id: "grandpa.botchan",
            person: .grandpa,
            request: [
                "孫がな、賢治の本をえらく気に入ってくれてのう",
                "わしも久しぶりに読みとうなった。若いころ読んだ、新米の先生が田舎の学校で大暴れする話……",
                "たしか、夏目漱石じゃったかのう。題名がのどまで出かかっとるんじゃが",
            ],
            summary: "新米の先生が田舎の学校で大暴れする、夏目漱石の話",
            hint: "夏目漱石の『坊っちゃん』のことなのだ。「な」の棚か、司書さんに題名でさがしてもらうのだ",
            thanks: [
                "そうそう、『坊っちゃん』じゃ！ 親譲りの無鉄砲で……ははは、出だしは覚えとるもんじゃのう",
                "ベンチでゆっくり読ませてもらうよ。ずんだもんさんは、本さがしの名人じゃな",
            ],
            wrongBook: "うーん、それじゃないのう。夏目漱石の、新米の先生の話なんじゃが",
            matches: title("坊っちゃん", author: "夏目漱石")
        ),

        // ユイさん
        BookWish(
            id: "student.akutagawa",
            person: .student,
            request: [
                "あ、ずんだもん。ちょうどよかった、聞いてくれる？",
                "国語のレポートで、芥川龍之介の作品を一つ読まなきゃいけないの",
                "でも、どれから読めばいいのか分からなくて……芥川の本を探してるんだよね",
            ],
            summary: "芥川龍之介の本（どれでも）",
            hint: "芥川の本なら、どれでもいいのだ。図書館では「芥川竜之介」と書くから、作家で「芥川」とさがすのだ。「あ」の棚にもあるのだ",
            thanks: [
                "芥川だ！ ありがとう、これでレポートが書ける",
                "……読んでみて、ちょっとこわくて、でもきれいな話だったら、ずんだもんにも教えるね",
            ],
            wrongBook: "ごめん、それはレポートに使えないんだ……芥川龍之介の作品じゃないと",
            matches: author("芥川竜之介")
        ),
        BookWish(
            id: "student.star",
            person: .student,
            request: [
                "レポート、無事に出せたよ。ずんだもんのおかげ",
                "それでね、最近ちょっと眠れなくて。夜にゆっくり読める、星が出てくるお話ってないかな",
            ],
            summary: "夜に読みたい、星が出てくるお話",
            hint: "題名に「星」が入っている本をさがすのだ。宮沢賢治の『よだかの星』なんかもあるのだ",
            thanks: [
                "星のお話……！ 今夜は、窓を少しあけて読んでみるね",
                "ずんだもん、本をえらぶの上手だね。司書さんになれるよ",
            ],
            wrongBook: "それもいいけど……今夜は星が出てくるお話が読みたいな",
            matches: titleContains(["星"])
        ),
    ]
}

/// 町の人からの頼まれごとと、届けるために借りている本を保存する
@Observable
final class ErrandStore {
    /// 引き受けた頼まれごと
    private(set) var accepted: Set<String> = []
    /// 届け終わった頼まれごと
    private(set) var delivered: Set<String> = []
    /// 届けるために図書館で借りて、かばんに入れている本
    private(set) var carrying: CatalogBook?

    private let defaults: UserDefaults
    private static let key = "errand.progress"

    private struct Progress: Codable {
        var accepted: Set<String>
        var delivered: Set<String>
        var carrying: CatalogBook?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let progress = try? JSONDecoder().decode(Progress.self, from: data) {
            accepted = progress.accepted
            delivered = progress.delivered
            carrying = progress.carrying
        }
    }

    /// その人がいま頼みたいこと（ぜんぶ届けたら nil）
    func currentWish(of person: Townsperson) -> BookWish? {
        BookWish.all.first { $0.person == person && !delivered.contains($0.id) }
    }

    func isAccepted(_ wish: BookWish) -> Bool {
        accepted.contains(wish.id)
    }

    /// 引き受けて、まだ届けていない頼まれごと
    var pendingWishes: [BookWish] {
        BookWish.all.filter { accepted.contains($0.id) && !delivered.contains($0.id) }
    }

    var deliveredCount: Int { delivered.count }

    /// 借りた本を待っている人がいるか（図書館で「かりる」を出すかどうか）
    var isLookingForBook: Bool { !pendingWishes.isEmpty }

    /// その本を待っている頼まれごと
    func wishes(matching book: CatalogBook) -> [BookWish] {
        pendingWishes.filter { $0.matches(book) }
    }

    func accept(_ wish: BookWish) {
        guard accepted.insert(wish.id).inserted else { return }
        save()
    }

    /// 本を借りてかばんに入れる。前に借りていた本は返す
    func borrow(_ book: CatalogBook) {
        carrying = book
        save()
    }

    /// 本を借りたときのずんだもんのひとこと。待っている人がいれば名前を出す
    func borrowNote(for book: CatalogBook) -> String {
        if let wish = wishes(matching: book).first {
            return "『\(book.title)』をかりたのだ。\(wish.person.name)に届けにいくのだ！"
        }
        return "『\(book.title)』をかりたのだ。……でも、たのまれた本とはちょっとちがうかもしれないのだ"
    }

    func returnBook() {
        carrying = nil
        save()
    }

    /// 借りている本を渡して、頼まれごとを終える
    func deliver(_ wish: BookWish) {
        delivered.insert(wish.id)
        carrying = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Progress(accepted: accepted, delivered: delivered, carrying: carrying)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
