import Foundation
import Observation

/// ストーリーの進み具合を表す目印。立った目印はアプリを閉じても残る
enum StoryFlag: String, Codable, CaseIterable {
    // 序章「字を見ると眠いのだ」
    /// 雨の夜に図書室に迷い込み、おフミさんと出会った
    case prologueMetFumi
    /// 迷子の子に「あおい えほん」を読んでほしいと頼まれた
    case prologueChildAsked
    /// 絵本を読んであげて、迷子の子が成仏した
    case prologueChildPassed
    /// 床に落ちていたしおりを拾った
    case prologueFoundBookmark
    /// しおりを隅の棚に挟んだ（終章への伏線）
    case prologueBookmarkShelved
    /// 序章を最後まで遊んだ
    case prologueCleared

    // 第1章「続きが気になるのだ」（走れメロス）
    /// タクと出会った
    case chapter1Started
    /// タクに、なくしたしおりを探すよう頼まれた
    case chapter1AskedBookmark
    /// タクのしおり（切符）を見つけた
    case chapter1FoundBookmark
    /// 本の中で濁流を泳ぎ切った
    case chapter1RiverCrossed
    /// 峠の山賊を切り抜けた
    case chapter1BanditsPassed
    /// 倒れたメロスが泉の水で立ち上がった
    case chapter1MelosRevived
    /// フィロストラトスに止められても走り続けた
    case chapter1PhilostratusPassed
    /// 刑場に間に合い、結末を見届けた
    case chapter1ReachedEnd
    /// 第1章を最後まで遊んだ
    case chapter1Cleared
    /// 部屋で本物の『走れメロス』を読むかたずねた
    case chapter1ReadOffered

    // 第2章「書き込みは、その人の足あとなのだ」（吾輩は猫である）
    /// 猫の幽霊タマと出会った
    case chapter2Started
    /// キヨさんの書き込みだらけの文庫本を受け取った
    case chapter2GotBook
    /// 書き込み①: 杉垣のそば（若いころ。おフミさんの字もある）
    case chapter2NoteHedge
    /// 書き込み②: 書斎で昼寝する主人（お嫁に来たころ）
    case chapter2NoteStudy
    /// 書き込み③: 台所の雑煮（タマが来たころ）
    case chapter2NoteKitchen
    /// 書き込み④: 三毛子（年をとってから）
    case chapter2NoteMikeko
    /// 書き込み⑤: 茶の間の火鉢（最後の書き込み）
    case chapter2NoteBrazier
    /// タマに読み聞かせをして、タマが成仏した
    case chapter2TamaPassed
    /// 第2章を最後まで遊んだ
    case chapter2Cleared
    /// 部屋で本物の『吾輩は猫である』を読むかたずねた
    case chapter2ReadOffered

    // 第3章「手紙は届くのだ」（銀河鉄道の夜）
    /// 手紙を持った少女の幽霊サチと出会った
    case chapter3Started
    /// サチの出せなかった手紙をあずかった
    case chapter3GotLetter
    /// 一両目: 車掌に切符（手紙）を見せた
    case chapter3TicketShown
    /// 二両目: 鳥捕りから雁のお菓子をもらった
    case chapter3CandyEaten
    /// 三両目: 燈台看守から苹果をもらった
    case chapter3AppleTaken
    /// 終点で作者に手紙を渡した
    case chapter3LetterDelivered
    /// サチが成仏した
    case chapter3SachiPassed
    /// 第3章を最後まで遊んだ
    case chapter3Cleared
    /// 部屋で本物の『銀河鉄道の夜』を読むかたずねた
    case chapter3ReadOffered
}

/// ストーリーで手に入るもちもの
enum StoryItem: String, Codable, CaseIterable, Identifiable {
    case pictureBook
    case bookmark
    case tatteredBook
    case ticketBookmark
    case annotatedBook
    case unsentLetter
    case apple

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pictureBook: "あおい えほん"
        case .bookmark: "おしばなの しおり"
        case .tatteredBook: "ボロボロの文庫本"
        case .ticketBookmark: "タクの しおり"
        case .annotatedBook: "書き込みだらけの文庫本"
        case .unsentLetter: "出せなかった手紙"
        case .apple: "苹果"
        }
    }

    var detail: String {
        switch self {
        case .pictureBook: "『ほしのこ ポロン』。表紙に小さなお星さまが描いてある絵本"
        case .bookmark: "押し花の入った古いしおり。どの本のものかは分からない"
        case .tatteredBook: "タクの『走れメロス』。川のところから先のページが破れている"
        case .ticketBookmark: "電車の切符。タクがしおりにしていた"
        case .annotatedBook: "キヨさんの『吾輩は猫である』。ページのあちこちに鉛筆の書き込みがある"
        case .unsentLetter: "サチが『銀河鉄道の夜』の作者に書いた手紙。切手はまだ貼られていない"
        case .apple: "燈台看守にもらった、黄金と紅の大きな苹果"
        }
    }

    /// アセットの画像名
    var imageName: String {
        switch self {
        case .pictureBook: "sprite_item_picture_book"
        case .bookmark: "sprite_item_bookmark"
        case .tatteredBook: "sprite_item_tattered_book"
        case .ticketBookmark: "sprite_item_ticket_bookmark"
        case .annotatedBook: "sprite_item_annotated_book"
        case .unsentLetter: "sprite_item_letter"
        case .apple: "sprite_item_apple"
        }
    }
}

/// ストーリーの進み具合ともちものを保存する
@Observable
final class StoryStore {
    private(set) var flags: Set<StoryFlag> = []
    private(set) var items: [StoryItem] = []
    /// ずんだもんが本に書いた書き込み（章の名前ごと）。クリア後の読書メモにも使う
    private(set) var memos: [String: String] = [:]

    private let defaults: UserDefaults
    private static let key = "story.progress"

    private struct Progress: Codable {
        var flags: Set<StoryFlag>
        var items: [StoryItem]
        /// あとから足したので、古い保存データにはない
        var memos: [String: String]?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let progress = try? JSONDecoder().decode(Progress.self, from: data) {
            flags = progress.flags
            items = progress.items
            memos = progress.memos ?? [:]
        }
    }

    func has(_ flag: StoryFlag) -> Bool {
        flags.contains(flag)
    }

    func set(_ flag: StoryFlag) {
        guard flags.insert(flag).inserted else { return }
        save()
    }

    func has(_ item: StoryItem) -> Bool {
        items.contains(item)
    }

    func give(_ item: StoryItem) {
        guard !items.contains(item) else { return }
        items.append(item)
        save()
    }

    func take(_ item: StoryItem) {
        items.removeAll { $0 == item }
        save()
    }

    func setMemo(_ memo: String, for chapter: String) {
        memos[chapter] = memo
        save()
    }

    /// 最初から遊び直す
    func reset() {
        flags = []
        items = []
        memos = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Progress(flags: flags, items: items, memos: memos)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
