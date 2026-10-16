import Foundation

/// 青空文庫の注記つきテキスト（ルビ《》・｜・［＃…］）をパースする
/// 仕様: https://www.aozora.gr.jp/annotation/
nonisolated enum AozoraTextParser {
    static func parse(_ source: String) -> AozoraDocument {
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        let (bodyLines, colophon) = splitSections(lines)
        var state = BlockState()
        var blocks: [AozoraBlock] = []

        for line in bodyLines {
            var parser = LineParser(line: line, state: state)
            blocks.append(contentsOf: parser.parse())
            state = parser.state
        }

        // 末尾の空行を落とす
        while case .paragraph(let paragraph)? = blocks.last, paragraph.isEmpty {
            blocks.removeLast()
        }
        // 奥付にも外字注記などが含まれるので同じパーサーを通す
        let colophonInlines = colophon.flatMap { line -> [[AozoraInline]] in
            var parser = LineParser(line: line, state: BlockState())
            return parser.parse().compactMap { block in
                guard case .paragraph(let paragraph) = block, !paragraph.isEmpty else { return nil }
                return paragraph.inlines
            }
        }
        return AozoraDocument(blocks: blocks, colophon: colophonInlines)
    }

    /// ヘッダ（題名・著者名と記号の説明）と奥付（底本：以降）を本文から切り離す
    private static func splitSections(_ lines: [String]) -> (body: [String], colophon: [String]) {
        var index = 0
        // 題名・著者名などのヘッダは最初の空行まで
        while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            index += 1
        }
        while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            index += 1
        }
        // 【テキスト中に現れる記号について】の区切り線ブロック
        if index < lines.count, lines[index].hasPrefix("-----") {
            index += 1
            while index < lines.count, !lines[index].hasPrefix("-----") {
                index += 1
            }
            index += 1
        }
        guard index < lines.count else { return (lines, []) }

        let rest = Array(lines[index...])
        guard let colophonStart = rest.lastIndex(where: { $0.hasPrefix("底本：") }) else {
            return (rest, [])
        }
        let colophon = rest[colophonStart...]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (Array(rest[..<colophonStart]), colophon)
    }
}

/// 複数行にまたがる字下げ・地付き指定の状態
nonisolated private struct BlockState {
    var indent: Int?
    var wrapIndent: Int?
    var endOffset: Int?
}

nonisolated private struct LineParser {
    private struct Frame {
        var style: AozoraStyle?
        var label: String
        var tokens: [AozoraInline] = []
    }

    private let characters: [Character]
    private(set) var state: BlockState

    private var frames: [Frame] = [Frame(style: nil, label: "")]
    private var buffer = ""
    /// ｜ による明示的なルビ開始位置以降の文字列を buffer に溜めている
    private var explicitRubyStart = false
    private var paragraph = AozoraParagraph()
    private var blocks: [AozoraBlock] = []
    private var sawBlockOnlyAnnotation = false

    init(line: String, state: BlockState) {
        characters = Array(line)
        self.state = state
    }

    mutating func parse() -> [AozoraBlock] {
        applyBlockState()
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case "｜":
                flushBuffer()
                explicitRubyStart = true
                index += 1
            case "《":
                if let close = findClose(from: index + 1, open: "《", close: "》") {
                    appendRuby(String(characters[(index + 1)..<close]))
                    index = close + 1
                } else {
                    buffer.append(character)
                    index += 1
                }
            case "※" where index + 2 < characters.count && characters[index + 1] == "［" && characters[index + 2] == "＃":
                if let close = findClose(from: index + 2, open: "［", close: "］") {
                    let annotation = String(characters[(index + 3)..<close])
                    flushBuffer()
                    appendToken(Self.gaiji(from: annotation))
                    index = close + 1
                } else {
                    buffer.append(character)
                    index += 1
                }
            case "［" where index + 1 < characters.count && characters[index + 1] == "＃":
                if let close = findClose(from: index + 1, open: "［", close: "］") {
                    let annotation = String(characters[(index + 2)..<close])
                    handleAnnotation(annotation, isAtLineStart: isLineEmptySoFar)
                    index = close + 1
                } else {
                    buffer.append(character)
                    index += 1
                }
            default:
                buffer.append(character)
                index += 1
            }
        }
        finishParagraph(force: !sawBlockOnlyAnnotation)
        return blocks
    }

    private var isLineEmptySoFar: Bool {
        buffer.isEmpty && frames.allSatisfy(\.tokens.isEmpty)
    }

    // MARK: - Inline building

    private mutating func flushBuffer() {
        guard !buffer.isEmpty else { return }
        appendToken(.text(buffer))
        buffer = ""
        explicitRubyStart = false
    }

    private mutating func appendToken(_ token: AozoraInline) {
        frames[frames.count - 1].tokens.append(token)
    }

    private mutating func appendRuby(_ reading: String) {
        if explicitRubyStart {
            let base = buffer
            buffer = ""
            explicitRubyStart = false
            appendToken(.ruby(base: base.isEmpty ? [] : [.text(base)], reading: reading))
            return
        }
        let baseLength = Self.rubyBaseLength(in: buffer)
        if baseLength == 0 {
            // 外字などの直後に付いたルビは直前のトークンを親文字にする
            if let last = frames[frames.count - 1].tokens.popLast() {
                appendToken(.ruby(base: [last], reading: reading))
            } else {
                appendToken(.ruby(base: [], reading: reading))
            }
            return
        }
        let splitIndex = buffer.index(buffer.endIndex, offsetBy: -baseLength)
        let prefix = String(buffer[..<splitIndex])
        let base = String(buffer[splitIndex...])
        buffer = ""
        if !prefix.isEmpty { appendToken(.text(prefix)) }
        appendToken(.ruby(base: [.text(base)], reading: reading))
    }

    /// ｜ がない場合、《 の直前にある同じ字種の連続を親文字とみなす
    private static func rubyBaseLength(in text: String) -> Int {
        guard let last = text.last else { return 0 }
        let kind = CharacterKind(last)
        var count = 0
        for character in text.reversed() {
            guard CharacterKind(character) == kind else { break }
            count += 1
        }
        return kind == .other ? 1 : count
    }

    private func findClose(from start: Int, open: Character, close: Character) -> Int? {
        var depth = 0
        var index = start
        while index < characters.count {
            if characters[index] == open {
                depth += 1
            } else if characters[index] == close {
                if depth <= 1 { return index }
                depth -= 1
            }
            index += 1
        }
        return nil
    }

    // MARK: - Annotations

    private mutating func handleAnnotation(_ rawAnnotation: String, isAtLineStart: Bool) {
        // 「対象」に〜 形式（前方参照型）。対象の文字列は本文と照合するので正規化しない
        if let match = rawAnnotation.firstMatch(of: #/^「(.+?)」(?:は|に|の)(.+)$/#) {
            handleTargetedAnnotation(target: String(match.1), command: Self.normalizeDigits(String(match.2)))
            return
        }

        let annotation = Self.normalizeDigits(rawAnnotation)

        if handleBlockAnnotation(annotation, isAtLineStart: isAtLineStart) { return }

        // 挿絵
        if annotation.contains("入る"), annotation.contains("（") {
            flushBuffer()
            appendToken(.note("［挿絵］"))
            return
        }

        // ［＃（ん）］のような入力者による補記
        if annotation.hasPrefix("（"), annotation.hasSuffix("）") {
            flushBuffer()
            appendToken(.note(annotation))
            return
        }

        // 見出し（範囲指定）
        if let match = annotation.firstMatch(of: #/^(?:同行|窓)?(大|中|小)見出し(終わり)?$/#) {
            if match.2 == nil { paragraph.headingLevel = Self.headingLevel(String(match.1)) }
            return
        }

        // 傍点・太字などの範囲指定
        if annotation.hasSuffix("終わり") {
            let label = String(annotation.dropLast(3))
            if let frameIndex = frames.lastIndex(where: { $0.label == label }), frameIndex > 0 {
                flushBuffer()
                while frames.count > frameIndex {
                    let frame = frames.removeLast()
                    if let style = frame.style {
                        appendToken(.styled(style, frame.tokens))
                    } else {
                        frames[frames.count - 1].tokens.append(contentsOf: frame.tokens)
                    }
                }
            }
            return
        }
        if let style = Self.style(for: annotation) {
            flushBuffer()
            frames.append(Frame(style: style, label: annotation))
            return
        }
        // その他の注記（底本の誤植についての注など）は表示しない
    }

    private mutating func handleTargetedAnnotation(target: String, command: String) {
        if let match = command.firstMatch(of: #/^(?:同行|窓)?(大|中|小)見出し$/#) {
            paragraph.headingLevel = Self.headingLevel(String(match.1))
            return
        }
        if let match = command.firstMatch(of: #/^「(.+)」の注記$/#) {
            let reading = String(match.1)
            wrapLastOccurrence(of: target) { .ruby(base: $0, reading: reading) }
            return
        }
        if let style = Self.style(for: command) {
            wrapLastOccurrence(of: target) { .styled(style, $0) }
        }
    }

    /// 字下げ・地付き・改ページなど行単位の注記。処理した場合は true
    private mutating func handleBlockAnnotation(_ annotation: String, isAtLineStart: Bool) -> Bool {
        if ["改ページ", "改丁", "改段", "改見開き"].contains(annotation) {
            finishParagraph(force: false)
            blocks.append(.pageBreak)
            sawBlockOnlyAnnotation = true
            return true
        }
        if annotation.hasPrefix("ここから") {
            let body = annotation.dropFirst(4)
            if let match = body.firstMatch(of: #/^(?:天から)?(\d+)字下げ(?:、折り返して(\d+)字下げ)?/#) {
                state.indent = Int(match.1)
                state.wrapIndent = match.2.flatMap { Int($0) }
            } else if let match = body.firstMatch(of: #/^改行天付き、折り返して(\d+)字下げ/#) {
                state.indent = 0
                state.wrapIndent = Int(match.1)
            } else if body.hasPrefix("地付き") {
                state.endOffset = 0
            } else if let match = body.firstMatch(of: #/^地から(\d+)字上げ/#) {
                state.endOffset = Int(match.1)
            } else {
                return false
            }
            sawBlockOnlyAnnotation = true
            applyBlockState()
            return true
        }
        if annotation.hasPrefix("ここで") {
            if annotation.contains("字下げ終わり") {
                state.indent = nil
                state.wrapIndent = nil
            } else if annotation.contains("地付き終わり") || annotation.contains("字上げ終わり") {
                state.endOffset = nil
            } else {
                return false
            }
            sawBlockOnlyAnnotation = true
            applyBlockState()
            return true
        }
        if let match = annotation.firstMatch(of: #/^(?:天から)?(\d+)字下げ$/#) {
            paragraph.indent = Int(match.1) ?? 0
            return true
        }
        let endOffset: Int? = if annotation == "地付き" {
            0
        } else if let match = annotation.firstMatch(of: #/^地から(\d+)字上げ$/#) {
            Int(match.1)
        } else {
            nil
        }
        if let endOffset {
            if !isAtLineStart {
                // 行の途中からの地付きは、そこから先を別の段落として地に寄せる
                finishParagraph(force: false)
                applyBlockState()
            }
            paragraph.endOffset = endOffset
            return true
        }
        return false
    }

    private mutating func applyBlockState() {
        guard paragraph.isEmpty, buffer.isEmpty else { return }
        paragraph.indent = state.indent ?? 0
        paragraph.wrapIndent = state.wrapIndent
        paragraph.endOffset = state.endOffset
    }

    /// 直前に出てきた target を探して transform で包む（「〇〇」に傍点 など）
    private mutating func wrapLastOccurrence(of target: String, transform: ([AozoraInline]) -> AozoraInline) {
        flushBuffer()
        var tokens = frames[frames.count - 1].tokens
        let fullText = tokens.map(\.baseText).joined()
        guard !target.isEmpty, let range = fullText.range(of: target, options: .backwards) else { return }
        let start = fullText.distance(from: fullText.startIndex, to: range.lowerBound)
        let end = fullText.distance(from: fullText.startIndex, to: range.upperBound)

        var before: [AozoraInline] = []
        var covered: [AozoraInline] = []
        var after: [AozoraInline] = []
        var position = 0
        for token in tokens {
            let length = token.baseText.count
            let tokenStart = position
            let tokenEnd = position + length
            position = tokenEnd

            if tokenEnd <= start {
                before.append(token)
            } else if tokenStart >= end {
                after.append(token)
            } else if case .text(let text) = token {
                let characters = Array(text)
                let localStart = max(0, start - tokenStart)
                let localEnd = min(length, end - tokenStart)
                if localStart > 0 { before.append(.text(String(characters[..<localStart]))) }
                covered.append(.text(String(characters[localStart..<localEnd])))
                if localEnd < length { after.append(.text(String(characters[localEnd...]))) }
            } else {
                covered.append(token)
            }
        }
        guard !covered.isEmpty else { return }
        tokens = before + [transform(covered)] + after
        frames[frames.count - 1].tokens = tokens
    }

    private mutating func finishParagraph(force: Bool) {
        flushBuffer()
        while frames.count > 1 {
            let frame = frames.removeLast()
            if let style = frame.style {
                appendToken(.styled(style, frame.tokens))
            } else {
                frames[frames.count - 1].tokens.append(contentsOf: frame.tokens)
            }
        }
        paragraph.inlines = frames[0].tokens
        frames[0].tokens = []
        if !paragraph.isEmpty || force {
            blocks.append(.paragraph(paragraph))
        }
        paragraph = AozoraParagraph()
    }

    // MARK: - Helpers

    private static func style(for command: String) -> AozoraStyle? {
        if command.hasSuffix("傍点") {
            let mark = switch command {
            case "白ゴマ傍点": "﹆"
            case "丸傍点": "●"
            case "白丸傍点": "○"
            case "黒三角傍点": "▲"
            case "白三角傍点": "△"
            case "二重丸傍点": "◎"
            case "蛇の目傍点": "◉"
            case "ばつ傍点": "×"
            default: "﹅"
            }
            return .emphasis(mark)
        }
        if command.hasSuffix("傍線") || command.hasSuffix("波線") || command.hasSuffix("破線") || command.hasSuffix("鎖線") {
            return .sideline
        }
        switch command {
        case "太字": return .bold
        case "斜体": return .italic
        case "縦中横": return .tateChuYoko
        case "下付き小文字": return .subscript
        case "上付き小文字": return .superscript
        default: return nil
        }
    }

    private static func headingLevel(_ size: String) -> Int {
        switch size {
        case "大": 1
        case "中": 2
        default: 3
        }
    }

    /// ※［＃「てへん＋劣」、第3水準1-85-7］ や ※［＃「口＋世」、U+546D、123-4］ のような外字注記
    private static func gaiji(from rawAnnotation: String) -> AozoraInline {
        let annotation = normalizeDigits(rawAnnotation)
        let description = annotation.firstMatch(of: #/「(.+?)」/#).map { String($0.1) }
            ?? annotation.split(separator: "、").first.map(String.init)
            ?? annotation
        if let match = annotation.firstMatch(of: #/U\+([0-9A-Fa-f]{4,6})/#),
           let scalarValue = UInt32(match.1, radix: 16),
           let scalar = Unicode.Scalar(scalarValue) {
            return .gaiji(character: String(Character(scalar)), description: description)
        }
        if let match = annotation.firstMatch(of: #/(?:^|[^\d-])([12])-(\d{1,2})-(\d{1,2})(?:$|[^\d-])/#),
           let plane = Int(match.1), let row = Int(match.2), let cell = Int(match.3),
           let character = JISX0213.character(plane: plane, row: row, cell: cell) {
            return .gaiji(character: character, description: description)
        }
        return .gaiji(character: nil, description: description)
    }

    private static func normalizeDigits(_ text: String) -> String {
        String(text.map { character -> Character in
            guard let scalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1,
                  (0xFF10...0xFF19).contains(scalar.value)
            else { return character }
            return Character(Unicode.Scalar(scalar.value - 0xFF10 + 0x30)!)
        })
    }
}

nonisolated private enum CharacterKind {
    case kanji, hiragana, katakana, alphabet, other

    init(_ character: Character) {
        guard let scalar = character.unicodeScalars.first else {
            self = .other
            return
        }
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2FFFF, 0xF900...0xFAFF,
             0x3005, 0x3006, 0x3007, 0x30F6, 0x4EDD: // 々 〆 〇 ヶ 仝
            self = .kanji
        case 0x3041...0x309F:
            self = .hiragana
        case 0x30A1...0x30FA, 0x30FC...0x30FF, 0x31F0...0x31FF:
            self = .katakana
        case 0x41...0x5A, 0x61...0x7A, 0x30...0x39, 0xFF21...0xFF3A, 0xFF41...0xFF5A, 0xFF10...0xFF19, 0xC0...0x24F:
            self = .alphabet
        default:
            self = .other
        }
    }
}
