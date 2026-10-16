import Foundation

/// 青空文庫の作品一覧に載っている1作品
nonisolated struct CatalogBook: Codable, Hashable, Identifiable, Sendable {
    /// 青空文庫の作品ID（例: "001567"）
    let id: String
    let title: String
    let titleYomi: String
    let titleSortKey: String
    let subtitle: String
    let authorID: String
    let authorName: String
    let authorYomi: String
    let authorSortKey: String
    let translatorName: String
    /// 文字遣い種別（例: "新字新仮名"）
    let kanaType: String
    /// 初出
    let firstAppearance: String
    let cardURL: URL
    let textURL: URL

    var displayTitle: String {
        subtitle.isEmpty ? title : "\(title)　\(subtitle)"
    }

    var displayCredit: String {
        translatorName.isEmpty ? authorName : "\(authorName)（\(translatorName) 訳）"
    }
}

/// 作家一覧の1人分
nonisolated struct CatalogAuthor: Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let yomi: String
    let sortKey: String
    let workCount: Int
}
