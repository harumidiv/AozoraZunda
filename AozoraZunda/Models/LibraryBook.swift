import Foundation

/// 端末にダウンロード済みの作品
nonisolated struct LibraryBook: Codable, Hashable, Identifiable, Sendable {
    let book: CatalogBook
    let downloadedAt: Date
    /// 読書位置（0.0〜1.0）
    var progress: Double = 0
    var lastOpenedAt: Date?

    var id: String { book.id }
}
