import Foundation

/// 青空文庫テキストをパースした結果。
/// 表示（HTML化）と、将来の読み上げ（ルビの読みを使ったテキスト化）の両方で使う中間表現。
nonisolated struct AozoraDocument: Sendable {
    var blocks: [AozoraBlock]
    /// 底本・入力者などの奥付（1行ずつ）
    var colophon: [[AozoraInline]]
}

nonisolated enum AozoraBlock: Sendable {
    case paragraph(AozoraParagraph)
    case pageBreak
}

nonisolated struct AozoraParagraph: Sendable {
    var inlines: [AozoraInline] = []
    /// 字下げ（字数）
    var indent: Int = 0
    /// 折り返し行の字下げ（nil なら indent と同じ）
    var wrapIndent: Int?
    /// 地付き・字上げ（nil なら通常、0 なら地付き、N なら地から N 字上げ）
    var endOffset: Int?
    /// 見出しレベル（1: 大見出し, 2: 中見出し, 3: 小見出し）
    var headingLevel: Int?

    var isEmpty: Bool { inlines.isEmpty }
}

nonisolated indirect enum AozoraInline: Sendable {
    case text(String)
    case ruby(base: [AozoraInline], reading: String)
    case styled(AozoraStyle, [AozoraInline])
    /// 外字。Unicode で表せる場合は character が入る
    case gaiji(character: String?, description: String)
    /// 挿絵など、本文中に表示する補足
    case note(String)

    /// ルビを除いた表示上の文字列
    var baseText: String {
        switch self {
        case .text(let text): text
        case .ruby(let base, _): base.map(\.baseText).joined()
        case .styled(_, let children): children.map(\.baseText).joined()
        case .gaiji(let character, _): character ?? "※"
        case .note: ""
        }
    }
}

nonisolated enum AozoraStyle: Sendable, Equatable {
    /// 傍点。値は傍点として打つ記号（例: ﹅）
    case emphasis(String)
    case sideline
    case bold
    case italic
    case tateChuYoko
    case `subscript`
    case superscript
}
