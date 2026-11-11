import Foundation

/// 夜の図書室で頼まれて、朝の現実世界（町・昼の図書館）で用意するもの。
/// 用意したものを持って、つぎの夜に図書室へ行くとストーリーが進む
enum StoryDayTask: CaseIterable {
    /// 第1章: 昼の図書館で『走れメロス』を借りる
    case melosBook
    /// 第2章: 公園のゲンさんのところで、タマの鈴を見つける
    case tamaBell
    /// 第3章: 図書館の前のユイさんから、切手をもらう
    case stamp
    /// 第4章: パン屋のミツさんから、兄弟へのおそなえものをもらう
    case anpan
    /// 第5章: 公園のゲンさんに、むかしの「はる」のことを聞く
    case haruRumor
    /// 終章: 昼の図書館で『手袋を買いに』を借りる
    case tebukuroBook

    /// いま朝にやること（なければ nil）
    static func current(_ story: StoryStore) -> StoryDayTask? {
        allCases.first { $0.isPending(story) }
    }

    func isPending(_ story: StoryStore) -> Bool {
        // 前のセーブデータで、すでに先へ進んでいるときは頼まれていないことにする
        story.has(askedFlag) && !story.has(doneFlag) && !isDelivered(story)
    }

    /// 夜に頼まれたときに立てる印
    var askedFlag: StoryFlag {
        switch self {
        case .melosBook: .chapter1AskedForBook
        case .tamaBell: .chapter2AskedForBell
        case .stamp: .chapter3AskedForStamp
        case .anpan: .chapter4AskedForFood
        case .haruRumor: .chapter5AskedFumi
        case .tebukuroBook: .finaleAskedForBook
        }
    }

    /// 朝に用意できたら立てる印
    var doneFlag: StoryFlag {
        switch self {
        case .melosBook: .chapter1BorrowedBook
        case .tamaBell: .chapter2GotBell
        case .stamp: .chapter3GotStamp
        case .anpan: .chapter4GotFood
        case .haruRumor: .chapter5HeardOfHaru
        case .tebukuroBook: .finaleBorrowedBook
        }
    }

    /// 手に入るもちもの
    var item: StoryItem? {
        switch self {
        case .melosBook: .melosBook
        case .tamaBell: .tamaBell
        case .stamp: .stamp
        case .anpan: .anpan
        case .haruRumor: nil
        case .tebukuroBook: .tebukuroBook
        }
    }

    /// 町で話しかける相手（昼の図書館で本を借りるときは nil）
    var person: Townsperson? {
        switch self {
        case .tamaBell, .haruRumor: .grandpa
        case .stamp: .student
        case .anpan: .baker
        case .melosBook, .tebukuroBook: nil
        }
    }

    /// 昼の図書館で借りる本か
    func wants(_ book: CatalogBook) -> Bool {
        switch self {
        case .melosBook: book.title == "走れメロス" && book.authorName.contains("太宰")
        case .tebukuroBook: book.title == "手袋を買いに" && book.authorName.contains("新美")
        default: false
        }
    }

    /// 昼の図書館で本を借りて、おつかいをすませる
    func borrow(into story: StoryStore) {
        if let item {
            story.give(item)
        }
        story.set(doneFlag)
    }

    /// 昼の図書館で、この本を借りるおつかいがあれば返す
    static func borrowing(_ book: CatalogBook, story: StoryStore) -> StoryDayTask? {
        guard let task = current(story), task.wants(book) else { return nil }
        return task
    }

    /// 本を借りたときのずんだもんのひとこと
    var borrowNote: String {
        switch self {
        case .melosBook: "『走れメロス』をかりたのだ。夜になったら、タクのところへ持っていくのだ！"
        case .tebukuroBook: "『手袋を買いに』をかりたのだ。……今夜、すみの棚に返しにいくのだ"
        default: ""
        }
    }

    /// 朝、部屋で目をさましたときのずんだもんのひとりごと
    var wakeUpLine: String {
        switch self {
        case .melosBook: "……朝なのだ。タクのために、町の図書館で『走れメロス』をかりてくるのだ。ちゃんとした、やぶれてない本なのだ"
        case .tamaBell: "……朝なのだ。タマの鈴、日なたのベンチって言ってたのだ。公園のゲンさんに聞いてみるのだ"
        case .stamp: "……朝なのだ。サチの手紙の切手……。図書館の前のユイさんなら、手紙のこと、くわしそうなのだ"
        case .anpan: "……朝なのだ。腹ぺこの兄弟に、おそなえもの。パン屋のミツさんのところへ行くのだ"
        case .haruRumor: "……朝なのだ。「はる」って、誰なのだ……。むかしのことなら、公園のゲンさんが知ってるかもしれないのだ"
        case .tebukuroBook: "……朝なのだ。町の図書館に、『手袋を買いに』があるはずなのだ。かりて、今夜すみの棚に返すのだ"
        }
    }

    /// 町にいるときの「いまやること」
    var townObjective: String {
        switch self {
        case .melosBook: "上の図書館で『走れメロス』（太宰治）をかりるのだ。夜になったら、タクに届けるのだ"
        case .tamaBell: "公園のゲンさんに、タマの鈴のことを聞いてみるのだ"
        case .stamp: "図書館の前のユイさんに、切手のことを聞いてみるのだ"
        case .anpan: "パン屋のミツさんに、兄弟へのおそなえものを頼むのだ"
        case .haruRumor: "公園のゲンさんに、むかしの「はる」のことを聞いてみるのだ"
        case .tebukuroBook: "上の図書館で『手袋を買いに』（新美南吉）をかりるのだ。夜になったら、すみの棚に返すのだ"
        }
    }

    /// 用意できたあと、夜までの「いまやること」
    var readyObjective: String {
        switch self {
        case .melosBook: "『走れメロス』をかりたのだ。夜になったら、タクに届けるのだ（部屋のベッドで夜まで待つ）"
        case .tamaBell: "タマの鈴を見つけたのだ。夜になったら、タマに届けるのだ（部屋のベッドで夜まで待つ）"
        case .stamp: "切手をもらったのだ。夜になったら、サチに届けるのだ（部屋のベッドで夜まで待つ）"
        case .anpan: "あんパンをもらったのだ。夜になったら、兄弟に届けるのだ（部屋のベッドで夜まで待つ）"
        case .haruRumor: "はるのことを聞いたのだ。夜になったら、図書室のすみの棚へ行くのだ（部屋のベッドで夜まで待つ）"
        case .tebukuroBook: "『手袋を買いに』をかりたのだ。夜になったら、すみの棚に返すのだ（部屋のベッドで夜まで待つ）"
        }
    }

    /// 朝に用意できて、まだ夜に持っていっていないもの
    static func ready(_ story: StoryStore) -> StoryDayTask? {
        allCases.first { story.has($0.doneFlag) && !$0.isDelivered(story) }
    }

    /// 夜に持っていって、ストーリーが先へ進んだか
    func isDelivered(_ story: StoryStore) -> Bool {
        switch self {
        case .melosBook: story.has(.chapter1BookReady)
        case .tamaBell: story.has(.chapter2GotBook)
        case .stamp: story.has(.chapter3GotLetter)
        case .anpan: story.has(.chapter4GotKey)
        case .haruRumor: story.has(.chapter5SawShadow)
        case .tebukuroBook: story.has(.finaleShelvedBook)
        }
    }
}
