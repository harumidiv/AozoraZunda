import CoreGraphics

nonisolated struct ReaderAppearance: Equatable, Sendable {
    var isVertical: Bool
    var fontSize: Double
    var theme: ReaderTheme
}

nonisolated enum ReaderTheme: String, CaseIterable, Identifiable, Sendable {
    case white
    case sepia
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white: "ホワイト"
        case .sepia: "セピア"
        case .dark: "ダーク"
        }
    }

    var background: CGColor {
        switch self {
        case .white: Self.rgb(0xFFFFFF)
        case .sepia: Self.rgb(0xF5ECD9)
        case .dark: Self.rgb(0x1C1C1E)
        }
    }

    var text: CGColor {
        switch self {
        case .white: Self.rgb(0x1A1A1A)
        case .sepia: Self.rgb(0x3B2F20)
        case .dark: Self.rgb(0xE5E5E7)
        }
    }

    /// ページ番号や注記など控えめな文字の色
    var subtle: CGColor {
        switch self {
        case .white: Self.rgb(0x8A8A8E)
        case .sepia: Self.rgb(0x8C7A60)
        case .dark: Self.rgb(0x8E8E93)
        }
    }

    private static func rgb(_ hex: Int) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
