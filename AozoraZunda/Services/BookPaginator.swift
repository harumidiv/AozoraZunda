import CoreText
import Foundation

/// 1ページの組版領域
nonisolated struct PageLayout: Equatable, Sendable {
    /// ページ全体の大きさ
    var pageSize: CGSize
    /// 本文を流し込む矩形（左上原点）
    var textRect: CGRect
    var isVertical: Bool
}

/// ページ分割済みの本。描画は1ページずつ CTFrame を作り直して行う
nonisolated final class PaginatedBook: @unchecked Sendable {
    struct Page {
        let section: Int
        let range: CFRange
        /// 本全体の中での先頭文字位置
        let location: Int
    }

    let pages: [Page]
    let totalLength: Int
    let layout: PageLayout
    /// 最後のページまで分割し終えているか（途中経過のときは false）
    let isComplete: Bool
    private let sections: [NSAttributedString]

    fileprivate init(pages: [Page], totalLength: Int, layout: PageLayout, isComplete: Bool, sections: [NSAttributedString]) {
        self.pages = pages
        self.totalLength = totalLength
        self.layout = layout
        self.isComplete = isComplete
        self.sections = sections
    }

    func makeFrame(forPage index: Int) -> CTFrame {
        let page = pages[index]
        let text = sections[page.section].attributedSubstring(from: NSRange(location: page.range.location, length: page.range.length))
        return BookPaginator.makeFrame(text, layout: layout)
    }

    /// 文字位置を含むページ
    func pageIndex(containing location: Int) -> Int {
        var low = 0
        var high = pages.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if pages[mid].location <= location {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return max(0, low)
    }

    /// 読書位置（0.0〜1.0）。最後のページでは 1.0
    func progress(atPage index: Int) -> Double {
        if isComplete, index == pages.count - 1 { return 1 }
        guard totalLength > 0 else { return 0 }
        return Double(pages[index].location) / Double(totalLength)
    }
}

nonisolated enum BookPaginator {
    /// ページ分割する。長編でもすぐ読み始められるよう、reportInterval ページごとに途中経過を onPartial で返す
    static func paginate(
        _ sections: [NSAttributedString],
        layout: PageLayout,
        reportInterval: Int = 40,
        onPartial: ((PaginatedBook) -> Void)? = nil
    ) -> PaginatedBook? {
        var pages: [PaginatedBook.Page] = []
        var offset = 0
        let totalLength = sections.reduce(0) { $0 + $1.length }

        for (sectionIndex, section) in sections.enumerated() {
            var start = 0
            var chunkLength = 1_024
            while start < section.length {
                if Task.isCancelled { return nil }
                // 長いセクション全体から framesetter を作ると非常に遅いので、
                // 1ページ分より少し多めの部分文字列だけを組んで、入りきった文字数を求める
                var length: Int
                while true {
                    let candidate = min(chunkLength, section.length - start)
                    let chunk = section.attributedSubstring(from: NSRange(location: start, length: candidate))
                    length = CTFrameGetVisibleStringRange(makeFrame(chunk, layout: layout)).length
                    if length < candidate || start + candidate >= section.length { break }
                    chunkLength *= 2
                }
                // 1文字も入らない場合でも無限ループしないよう最低1文字は進める
                length = max(1, length)
                pages.append(.init(section: sectionIndex, range: CFRange(location: start, length: length), location: offset + start))
                start += length
                if let onPartial, pages.count % reportInterval == 0 {
                    onPartial(PaginatedBook(pages: pages, totalLength: totalLength, layout: layout, isComplete: false, sections: sections))
                }
            }
            offset += section.length
        }
        guard !pages.isEmpty else { return nil }
        return PaginatedBook(pages: pages, totalLength: totalLength, layout: layout, isComplete: true, sections: sections)
    }

    static func makeFrame(_ text: NSAttributedString, layout: PageLayout) -> CTFrame {
        // CoreText は左下原点なので矩形を反転して渡す
        let rect = CGRect(
            x: layout.textRect.minX,
            y: layout.pageSize.height - layout.textRect.maxY,
            width: layout.textRect.width,
            height: layout.textRect.height
        )
        var attributes: [CFString: Any] = [:]
        if layout.isVertical {
            attributes[kCTFrameProgressionAttributeName] = CTFrameProgression.rightToLeft.rawValue
        }
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        return CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: rect, transform: nil), attributes as CFDictionary)
    }

    /// CGContext（左下原点）にページを描く。
    /// CTFrameDraw ではルビのある行だけ基準線がずれて行間が不揃いになるので、1行ずつ位置を補正して描く
    static func draw(_ book: PaginatedBook, page index: Int, in context: CGContext) {
        let frame = book.makeFrame(forPage: index)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(), &origins)
        let pathOrigin = CTFrameGetPath(frame).boundingBox.origin
        let isVertical = book.layout.isVertical

        for (line, origin) in zip(lines, origins) {
            // ルビで増えた分だけ行の基準線が送り方向にずれるので戻す
            let shift = rubyExtraAscent(of: line)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(
                x: pathOrigin.x + origin.x + (isVertical ? shift : 0),
                y: pathOrigin.y + origin.y + (isVertical ? 0 : shift)
            )
            if isVertical {
                context.rotate(by: -.pi / 2)
            }
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    private static func rubyExtraAscent(of line: CTLine) -> CGFloat {
        var lineAscent: CGFloat = 0
        CTLineGetTypographicBounds(line, &lineAscent, nil, nil)
        var fontAscent: CGFloat = 0
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let font = attributes[kCTFontAttributeName] else { continue }
            fontAscent = max(fontAscent, CTFontGetAscent(font as! CTFont))
        }
        return fontAscent > 0 ? max(0, lineAscent - fontAscent) : 0
    }
}
