import CoreText
import Foundation

/// AozoraDocument を CoreText で組版するための属性付き文字列に変換する。
/// 改ページ位置で区切った「セクション」の配列を返し、各セクションは新しいページから始まる。
nonisolated enum AozoraAttributedRenderer {
    static func render(_ document: AozoraDocument, title: String, credit: String, appearance: ReaderAppearance) -> [NSAttributedString] {
        var context = Context(appearance: appearance)
        var sections: [NSAttributedString] = [context.coverPage(title: title, credit: credit)]

        var current = NSMutableAttributedString()
        for block in document.blocks {
            switch block {
            case .pageBreak:
                if current.length > 0 { sections.append(current) }
                current = NSMutableAttributedString()
            case .paragraph(let paragraph):
                context.appendParagraph(paragraph, to: current)
            }
        }
        if current.length > 0 { sections.append(current) }

        if !document.colophon.isEmpty {
            let colophon = NSMutableAttributedString()
            for line in document.colophon {
                context.appendColophonLine(line, to: colophon)
            }
            sections.append(colophon)
        }
        return sections
    }
}

nonisolated private struct Context {
    let appearance: ReaderAppearance
    let fontSize: CGFloat
    let lineHeight: CGFloat
    private var fontCache: [FontKey: CTFont] = [:]

    private struct FontKey: Hashable {
        let size: CGFloat
        let bold: Bool
    }

    init(appearance: ReaderAppearance) {
        self.appearance = appearance
        fontSize = appearance.fontSize
        lineHeight = (appearance.fontSize * 1.75).rounded()
    }

    // MARK: - Sections

    mutating func coverPage(title: String, credit: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let titleSize = fontSize * 1.6
        var titleAttributes = baseAttributes(font: font(size: titleSize, bold: true), color: appearance.theme.text)
        titleAttributes[.ctParagraphStyle] = paragraphStyle(
            indent: 3, wrapIndent: 3, endOffset: nil, lineHeight: (titleSize * 1.6).rounded(), spacingAfter: lineHeight
        )
        result.append(NSAttributedString(string: title + "\n", attributes: titleAttributes))

        var creditAttributes = baseAttributes(font: font(size: fontSize * 1.1, bold: false), color: appearance.theme.text)
        creditAttributes[.ctParagraphStyle] = paragraphStyle(indent: 0, wrapIndent: 0, endOffset: 2, lineHeight: lineHeight)
        result.append(NSAttributedString(string: credit + "\n", attributes: creditAttributes))
        return result
    }

    mutating func appendParagraph(_ paragraph: AozoraParagraph, to output: NSMutableAttributedString) {
        let start = output.length
        let headingScale: CGFloat? = paragraph.headingLevel.map { [1.45, 1.3, 1.15][min($0, 3) - 1] }
        let size = fontSize * (headingScale ?? 1)
        let attributes = baseAttributes(font: font(size: size, bold: headingScale != nil), color: appearance.theme.text)

        appendInlines(paragraph.inlines, attributes: attributes, to: output)
        output.append(NSAttributedString(string: "\n", attributes: attributes))

        let style = paragraphStyle(
            indent: paragraph.indent,
            wrapIndent: paragraph.wrapIndent ?? paragraph.indent,
            endOffset: paragraph.endOffset,
            lineHeight: headingScale == nil ? lineHeight : (size * 1.75).rounded(),
            spacingBefore: headingScale != nil ? lineHeight * 0.5 : 0,
            spacingAfter: headingScale != nil ? lineHeight * 0.5 : 0
        )
        output.addAttribute(.ctParagraphStyle, value: style, range: NSRange(location: start, length: output.length - start))
    }

    mutating func appendColophonLine(_ inlines: [AozoraInline], to output: NSMutableAttributedString) {
        let start = output.length
        let size = fontSize * 0.75
        let attributes = baseAttributes(font: font(size: size, bold: false), color: appearance.theme.subtle)
        appendInlines(inlines, attributes: attributes, to: output)
        output.append(NSAttributedString(string: "\n", attributes: attributes))
        output.addAttribute(
            .ctParagraphStyle,
            value: paragraphStyle(indent: 0, wrapIndent: 1, endOffset: nil, lineHeight: (size * 1.7).rounded()),
            range: NSRange(location: start, length: output.length - start)
        )
    }

    // MARK: - Inlines

    private mutating func appendInlines(_ inlines: [AozoraInline], attributes: [NSAttributedString.Key: Any], to output: NSMutableAttributedString) {
        for inline in inlines {
            appendInline(inline, attributes: attributes, to: output)
        }
    }

    private mutating func appendInline(_ inline: AozoraInline, attributes: [NSAttributedString.Key: Any], to output: NSMutableAttributedString) {
        switch inline {
        case .text(let text):
            output.append(NSAttributedString(string: text, attributes: attributes))

        case .ruby(let base, let reading):
            let start = output.length
            appendInlines(base, attributes: attributes, to: output)
            let range = NSRange(location: start, length: output.length - start)
            guard range.length > 0 else {
                output.append(NSAttributedString(string: "（\(reading)）", attributes: attributes))
                return
            }
            output.addAttribute(.ctRuby, value: ruby(reading, color: attributes[.ctForegroundColor]), range: range)
            // 傍点もルビとして描くので、読み上げで使う本当の読みは別の属性に持たせる
            output.addAttribute(.speechReading, value: reading, range: range)

        case .styled(let style, let children):
            var styledAttributes = attributes
            let baseFont = attributes[.ctFont] as! CTFont
            let baseSize = CTFontGetSize(baseFont)
            switch style {
            case .bold:
                styledAttributes[.ctFont] = font(size: baseSize, bold: true)
            case .subscript, .superscript:
                styledAttributes[.ctFont] = font(size: baseSize * 0.6, bold: false)
                styledAttributes[.ctBaselineOffset] = style == .subscript ? -baseSize * 0.15 : baseSize * 0.35
            case .sideline:
                styledAttributes[.ctUnderlineStyle] = CTUnderlineStyle.single.rawValue
            case .emphasis, .italic, .tateChuYoko:
                break
            }
            let start = output.length
            appendInlines(children, attributes: styledAttributes, to: output)
            if case .emphasis(let mark) = style {
                addEmphasis(mark, range: NSRange(location: start, length: output.length - start), color: attributes[.ctForegroundColor], to: output)
            }

        case .gaiji(let character, let description):
            if let character {
                output.append(NSAttributedString(string: character, attributes: attributes))
            } else {
                output.append(NSAttributedString(string: "※〔\(description)〕", attributes: noteAttributes(from: attributes)))
            }

        case .note(let text):
            output.append(NSAttributedString(string: text, attributes: noteAttributes(from: attributes)))
        }
    }

    /// 傍点は1文字ずつルビとして記号を振る（CoreText に傍点の機能がないため）
    private func addEmphasis(_ mark: String, range: NSRange, color: Any?, to output: NSMutableAttributedString) {
        let string = output.string as NSString
        string.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { _, characterRange, _, _ in
            guard output.attribute(.ctRuby, at: characterRange.location, effectiveRange: nil) == nil else { return }
            output.addAttribute(.ctRuby, value: ruby(mark, color: color), range: characterRange)
        }
    }

    private mutating func noteAttributes(from attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var result = attributes
        let baseSize = CTFontGetSize(attributes[.ctFont] as! CTFont)
        result[.ctFont] = font(size: baseSize * 0.6, bold: false)
        result[.ctForegroundColor] = appearance.theme.subtle
        return result
    }

    // MARK: - Attributes

    private func baseAttributes(font: CTFont, color: CGColor) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .ctFont: font,
            .ctForegroundColor: color,
        ]
        if appearance.isVertical {
            attributes[.ctVerticalForms] = true
        }
        return attributes
    }

    private func ruby(_ text: String, color: Any?) -> CTRubyAnnotation {
        var attributes: [CFString: Any] = [kCTRubyAnnotationSizeFactorAttributeName: 0.5]
        if let color { attributes[kCTForegroundColorAttributeName] = color }
        return CTRubyAnnotationCreateWithAttributes(.auto, .auto, .before, text as CFString, attributes as CFDictionary)
    }

    private mutating func font(size: CGFloat, bold: Bool) -> CTFont {
        let key = FontKey(size: size, bold: bold)
        if let cached = fontCache[key] { return cached }
        let font = CTFontCreateWithName((bold ? "HiraMinProN-W6" : "HiraMinProN-W3") as CFString, size, nil)
        fontCache[key] = font
        return font
    }

    private func paragraphStyle(
        indent: Int,
        wrapIndent: Int,
        endOffset: Int?,
        lineHeight: CGFloat,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) -> CTParagraphStyle {
        var alignment: CTTextAlignment = endOffset == nil ? .natural : .right
        // 行送りを lineHeight に固定する（フォントの leading は加えない）
        let specifiers: [CTParagraphStyleSpecifier] = [
            .firstLineHeadIndent, .headIndent, .tailIndent,
            .minimumLineHeight, .maximumLineHeight,
            .minimumLineSpacing, .maximumLineSpacing,
            .paragraphSpacingBefore, .paragraphSpacing,
        ]
        let values: [CGFloat] = [
            CGFloat(indent) * fontSize, CGFloat(wrapIndent) * fontSize, -CGFloat(endOffset ?? 0) * fontSize,
            lineHeight, lineHeight,
            0, 0,
            spacingBefore, spacingAfter,
        ]
        return values.withUnsafeBufferPointer { valueBuffer in
            withUnsafeBytes(of: &alignment) { alignmentBytes in
                var settings = specifiers.indices.map { index in
                    CTParagraphStyleSetting(
                        spec: specifiers[index],
                        valueSize: MemoryLayout<CGFloat>.size,
                        value: valueBuffer.baseAddress! + index
                    )
                }
                settings.append(CTParagraphStyleSetting(
                    spec: .alignment,
                    valueSize: MemoryLayout<CTTextAlignment>.size,
                    value: alignmentBytes.baseAddress!
                ))
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
    }
}

nonisolated extension NSAttributedString.Key {
    static let ctFont = NSAttributedString.Key(kCTFontAttributeName as String)
    static let ctForegroundColor = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    static let ctParagraphStyle = NSAttributedString.Key(kCTParagraphStyleAttributeName as String)
    static let ctVerticalForms = NSAttributedString.Key(kCTVerticalFormsAttributeName as String)
    static let ctRuby = NSAttributedString.Key(kCTRubyAnnotationAttributeName as String)
    static let ctUnderlineStyle = NSAttributedString.Key(kCTUnderlineStyleAttributeName as String)
    static let ctBaselineOffset = NSAttributedString.Key(kCTBaselineOffsetAttributeName as String)
    /// ルビの読み（読み上げのときに親文字の代わりに読む）
    static let speechReading = NSAttributedString.Key("AozoraSpeechReading")
}
