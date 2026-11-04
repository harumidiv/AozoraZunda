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
}

/// ストーリーで手に入るもちもの
enum StoryItem: String, Codable, CaseIterable, Identifiable {
    case pictureBook
    case bookmark
    case tatteredBook
    case ticketBookmark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pictureBook: "あおい えほん"
        case .bookmark: "おしばなの しおり"
        case .tatteredBook: "ボロボロの文庫本"
        case .ticketBookmark: "タクの しおり"
        }
    }

    var detail: String {
        switch self {
        case .pictureBook: "『ほしのこ ポロン』。表紙に小さなお星さまが描いてある絵本"
        case .bookmark: "押し花の入った古いしおり。どの本のものかは分からない"
        case .tatteredBook: "タクの『走れメロス』。川のところから先のページが破れている"
        case .ticketBookmark: "電車の切符。タクがしおりにしていた"
        }
    }

    /// アセットの画像名
    var imageName: String {
        switch self {
        case .pictureBook: "sprite_item_picture_book"
        case .bookmark: "sprite_item_bookmark"
        case .tatteredBook: "sprite_item_tattered_book"
        case .ticketBookmark: "sprite_item_ticket_bookmark"
        }
    }
}

/// ストーリーの進み具合ともちものを保存する
@Observable
final class StoryStore {
    private(set) var flags: Set<StoryFlag> = []
    private(set) var items: [StoryItem] = []

    private let defaults: UserDefaults
    private static let key = "story.progress"

    private struct Progress: Codable {
        var flags: Set<StoryFlag>
        var items: [StoryItem]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let progress = try? JSONDecoder().decode(Progress.self, from: data) {
            flags = progress.flags
            items = progress.items
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

    /// 最初から遊び直す
    func reset() {
        flags = []
        items = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Progress(flags: flags, items: items)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
