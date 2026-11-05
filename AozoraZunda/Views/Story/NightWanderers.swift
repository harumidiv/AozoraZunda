import CoreGraphics

/// 夜間図書室をうろうろしている、ストーリーには関係のない幽霊。
/// 話しかけると、ひとことだけ図書室のうわさ話をしてくれる
enum NightWanderer: String, CaseIterable {
    /// 本を読みながら歩き回るおじいさん
    case bookworm
    /// 試験勉強をしている書生さん
    case shosei
    /// 待ち合わせをしている大正のお嬢さん
    case haikara
    /// ふわふわ漂うひとだま
    case wisp

    var name: String {
        switch self {
        case .bookworm: "立ち読みじいさん"
        case .shosei: "書生さん"
        case .haikara: "ハイカラさん"
        case .wisp: "ひとだま"
        }
    }

    var prompt: String {
        switch self {
        case .bookworm: "立ち読みじいさん ── 本を読みながら、ふらふら歩いているのだ"
        case .shosei: "書生さん ── ぶつぶつ何かを暗記しているのだ"
        case .haikara: "ハイカラさん ── 大きなリボンの、きれいな人なのだ"
        case .wisp: "ひとだま ── ぽわぽわ光っているのだ"
        }
    }

    var frames: [String] {
        ["wanderer_\(rawValue)_0", "wanderer_\(rawValue)_1"]
    }

    /// この幽霊が出てくるようになる進み具合（夜を重ねるごとに、図書室がにぎやかになる）
    var appearsAfter: StoryFlag {
        switch self {
        case .bookworm, .wisp: .prologueMetFumi
        case .shosei: .prologueCleared
        case .haikara: .chapter1Cleared
        }
    }

    /// 1マスを進むのにかける秒数
    var secondsPerTile: Double {
        switch self {
        case .bookworm: 1.6
        case .shosei: 1.1
        case .haikara: 1.3
        case .wisp: 0.6
        }
    }

    /// 曲がり角で立ち止まる時間
    var pause: ClosedRange<Double> {
        switch self {
        case .bookworm: 2.0...4.0
        case .shosei: 0.6...1.6
        case .haikara: 1.2...2.6
        case .wisp: 0.0...0.4
        }
    }

    /// 歩き回る道（マス座標の足元の位置）。最後まで行ったら最初に戻る
    var route: [(column: CGFloat, row: CGFloat)] {
        switch self {
        // 本棚の前を、本を眺めながら行ったり来たり
        case .bookworm: [(2.5, 6.3), (6.0, 6.3), (11.0, 6.3), (14.2, 6.3), (11.0, 6.3), (6.0, 6.3)]
        // 閲覧机のまわりから、カーペットのほうへ
        case .shosei: [(1.8, 10.8), (5.3, 10.8), (5.3, 9.4), (10.4, 9.4), (10.4, 11.2), (5.3, 11.2)]
        // 右の窓ぎわと、カウンターの横
        case .haikara: [(14.4, 6.2), (14.4, 8.7), (10.6, 8.7), (10.6, 6.2)]
        // 絵本の棚の前をくるくる（入口のそばのずんだもんにくっつかないよう、少し離れたところ）
        case .wisp: [(14.2, 12.3), (11.8, 12.3), (11.8, 11.2), (14.2, 11.2)]
        }
    }

    /// 話しかけたときのセリフ。話しかけるたびに次のセリフになる。
    /// 進み具合によって増えるセリフは先に言う
    func lines(_ flags: Set<StoryFlag>) -> [String] {
        var extra: [String] = []
        switch self {
        case .bookworm:
            if flags.contains(.chapter1Cleared) {
                extra.append("閲覧机の坊主、最近見かけんのう。……そうか、読み終えたか。ええことじゃ")
            }
            return extra + [
                "わしはな、この図書室の本をぜんぶ読むまで成仏せんと決めたんじゃ。……あと三万冊くらいかのう",
                "本は座って読むより、歩きながら読むのがええ。幽霊は人にぶつからんからの",
                "おフミさんに、貸出期限を六十年すぎとると叱られてしもうた",
                "おぬし、字を見ると眠くなるそうじゃな。……わしもじゃ。だから死んでも読み終わらん",
            ]
        case .shosei:
            if flags.contains(.chapter2Cleared) {
                extra.append("猫の声が聞こえなくなったね。静かすぎるのも、少しさみしい")
            }
            return extra + [
                "しーっ。試験勉強中なんだ。……もう百年くらい、試験は受けていないけれど",
                "ここの棚の並びは、ぼくが生きていた頃とほとんど変わらない。安心するよ",
                "きみ、ずんだもんというのか。……ずんだ餅は、生きているうちに食べておけばよかった",
            ]
        case .haikara:
            if flags.contains(.chapter3Cleared) {
                extra.append("手紙を持ったお嬢さん、届けられたのね。……うらやましいわ")
            }
            return extra + [
                "ごきげんよう。今夜はどんな恋のお話を読もうかしら",
                "雨の夜は好きよ。窓の雨音が、ページをめくる音に似ているもの",
                "わたくし、ここで待ち合わせをしているの。……ずいぶん昔から",
            ]
        case .wisp:
            return [
                "……ぽわ。",
                "……ぽわわ。（なんだか、あたたかいのだ）",
                "……（ずんだもんのまわりを、くるりと一周した）",
            ]
        }
    }
}
