import SpriteKit

/// 夜間図書室で調べられるもの
enum NightLibraryInteractable: WalkInteractable {
    case fumi
    case child
    /// 上の列の本棚（3 は右奥の「すみの棚」）
    case bookshelf(Int)
    case pictureBookShelf
    /// 床に落ちているしおり
    case bookmark
    case exit

    static let cornerShelf = 3

    var prompt: String {
        switch self {
        case .fumi: "おフミさん ── むかしの司書さん。透けているのだ"
        case .child: "まいごの子 ── しくしく泣いているのだ"
        case .bookshelf(Self.cornerShelf): "すみの棚 ── 古い本がぎっしり並んでいるのだ"
        case .bookshelf: "本棚 ── むずかしそうな本がぎっしりなのだ"
        case .pictureBookShelf: "絵本の棚 ── 表紙が見えるように並んでいるのだ"
        case .bookmark: "床で何かが光っているのだ"
        case .exit: "入口 ── ずんだもんの部屋に帰るのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .fumi, .child: "はなす"
        case .bookmark: "ひろう"
        case .exit: "かえる"
        default: "しらべる"
        }
    }

    var triggersOnEnter: Bool {
        self == .exit
    }
}

/// 雨の夜だけ開く図書室のマップ。ストーリーの舞台
final class NightLibraryScene: WalkScene<NightLibraryInteractable> {
    private let flags: Set<StoryFlag>
    private let fumi = SKSpriteNode()
    private let child = SKSpriteNode()
    private let bookmarkSparkle = SKSpriteNode()
    private var cornerShelfNode: SKSpriteNode?

    private static let shelfColumns: [CGFloat] = [2, 5, 10, 13]
    private static let shelfRow: CGFloat = 3

    /// flags: 開いた時点の進み具合。幽霊やしおりを出すかどうかを決める
    init(flags: Set<StoryFlag>) {
        self.flags = flags
        super.init(columns: 16, rows: 14, playerStart: (8, 11.1))
        backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1)
    }

    override func buildMap() {
        buildRoom()
        buildFurniture()
        buildLighting()
        buildCharacters()
    }

    private func buildRoom() {
        for row in 2..<(rows - 1) {
            for column in 1..<(columns - 1) {
                let variant = (row * 7 + column * 3) % 3
                place("floor_\(variant)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for column in 1..<(columns - 1) {
            place("night_wall_upper", column: CGFloat(column), row: 0, z: -9_000)
            place("wall_lower", column: CGFloat(column), row: 1, z: -9_000)
        }
        for row in 0..<rows {
            place("wall_side", column: 0, row: CGFloat(row), z: -8_000)
            place("wall_side", column: CGFloat(columns - 1), row: CGFloat(row), z: -8_000)
        }
        let entrance = 7...8
        for column in 1..<(columns - 1) where !entrance.contains(column) {
            place("wall_side", column: CGFloat(column), row: CGFloat(rows - 1), z: 5_000)
        }
        for column in entrance {
            place("floor_0", column: CGFloat(column), row: CGFloat(rows - 1), z: -10_000)
        }
        // 雨の降る窓
        let rain = (0..<3).map { Self.texture("rain_window_\($0)") }
        for column in [2.5, 11.5] {
            let window = place("rain_window_0", column: column, row: 0, z: -8_500)
            window.run(.repeatForever(.animate(with: rain, timePerFrame: 0.16)))
        }
        place("clock", column: 7.5, row: 0.4, z: -8_500)

        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 2.25)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
    }

    private func buildFurniture() {
        place("night_rug", column: 6, row: 9, z: -9_500)
        place("doormat", column: 7, row: 12.5, z: -9_500)
        addZone(column: 6.5, row: 11.9, width: 3, height: 1.5, interactable: .exit, anchor: (8, 11.4))

        for (index, column) in Self.shelfColumns.enumerated() {
            let shelf = place("bookshelf_\((index + 1) % 4)", column: column, row: Self.shelfRow)
            if index == NightLibraryInteractable.cornerShelf {
                cornerShelfNode = shelf
            }
            addObstacle(column: column, row: Self.shelfRow + 1, width: 2, height: 1)
            addZone(
                column: column - 0.25, row: Self.shelfRow + 1.9, width: 2.5, height: 1.2,
                interactable: .bookshelf(index), anchor: (column + 1, Self.shelfRow - 0.6)
            )
        }
        if flags.contains(.prologueBookmarkShelved) {
            showShelvedBookmark()
        }

        // 貸出カウンター（おフミさんがいる）
        place("counter", column: 6.5, row: 7)
        addObstacle(column: 6.5, row: 7.5, width: 3, height: 1)

        // 閲覧机と椅子
        place("table", column: 2, row: 6.8)
        place("chair", column: 1, row: 7.1)
        place("chair", column: 4, row: 7.1)
        addObstacle(column: 1, row: 7.3, width: 5, height: 1)

        // 絵本の棚
        place("picture_book_shelf", column: 11.5, row: 9.2)
        addObstacle(column: 11.5, row: 9.9, width: 2, height: 0.8)
        addZone(column: 11.25, row: 10.7, width: 2.5, height: 1.2, interactable: .pictureBookShelf, anchor: (12.5, 8.8))
    }

    /// 部屋全体を夜の色で暗くし、ランプのまわりだけ明るくする
    private func buildLighting() {
        let night = SKSpriteNode(color: SKColor(red: 0.52, green: 0.57, blue: 0.86, alpha: 1), size: CGSize(width: 4_000, height: 4_000))
        night.blendMode = .multiply
        night.zPosition = 9_000
        addToCamera(night)

        let flames = [Self.texture("lamp_0"), Self.texture("lamp_1")]
        for (column, row) in [(8.0, 3.4), (14.0, 6.5), (1.0, 9.6)] {
            let lamp = place("lamp_0", column: column, row: row)
            lamp.run(.repeatForever(.animate(with: flames, timePerFrame: 0.3)))
            addObstacle(column: column + 0.2, row: row + 1.1, width: 0.6, height: 0.4)

            let glow = SKSpriteNode(texture: Self.texture("glow_warm"))
            glow.position = point(column: column + 0.5, row: row + 0.15)
            glow.blendMode = .add
            glow.zPosition = 9_500
            glow.setScale(1.25)
            glow.alpha = 0.7
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 0.5),
                .fadeAlpha(to: 0.7, duration: 0.4),
            ])))
            addToWorld(glow)
        }
    }

    private func buildCharacters() {
        setUpGhost(fumi, frames: ["fumi_0", "fumi_1"], at: point(column: 8, row: 7.3))
        if flags.contains(.prologueMetFumi) {
            showFumiZone()
        } else {
            fumi.alpha = 0
        }

        if !flags.contains(.prologueChildPassed) {
            setUpGhost(child, frames: ["child_cry_0", "child_cry_1"], at: point(column: 3, row: 11))
            addZone(column: 2, row: 11.2, width: 2, height: 1.5, interactable: .child, anchor: (3, 9.6))
        }

        if flags.contains(.prologueChildPassed) && !flags.contains(.prologueFoundBookmark) {
            showBookmarkSparkle()
        }
    }

    // MARK: - 幽霊

    private func setUpGhost(_ ghost: SKSpriteNode, frames: [String], at position: CGPoint) {
        ghost.texture = Self.texture(frames[0])
        ghost.size = CGSize(width: 16, height: 16)
        ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
        ghost.position = position
        ghost.zPosition = Self.depth(forBaseY: position.y)
        ghost.alpha = 0.92

        // 暗い部屋でもぼんやり光って見えるように
        let halo = SKSpriteNode(texture: Self.texture("glow_ghost"))
        halo.name = "halo"
        halo.position = CGPoint(x: 0, y: 8)
        halo.blendMode = .add
        halo.alpha = 0.45
        halo.zPosition = 9_000
        ghost.addChild(halo)

        // 夜の暗さに沈まないよう、同じ絵を薄く重ねてぼんやり光らせる
        let shine = SKSpriteNode(texture: ghost.texture)
        shine.name = "shine"
        shine.anchorPoint = ghost.anchorPoint
        shine.size = ghost.size
        shine.alpha = 0.55
        shine.zPosition = 9_001
        ghost.addChild(shine)
        animateGhost(ghost, frames: frames)

        // ふわふわ浮かぶ
        ghost.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 1.5, duration: 0.9),
            .moveBy(x: 0, y: -1.5, duration: 0.9),
        ])), withKey: "float")
        addToWorld(ghost)
    }

    private func animateGhost(_ ghost: SKSpriteNode, frames: [String]) {
        let animation = SKAction.repeatForever(.animate(with: frames.map { Self.texture($0) }, timePerFrame: 0.45))
        ghost.run(animation, withKey: "frames")
        ghost.childNode(withName: "shine")?.run(animation, withKey: "frames")
    }

    private func showFumiZone() {
        addZone(column: 6, row: 8.4, width: 4, height: 1.8, interactable: .fumi, anchor: (8, 5.9))
    }

    /// おフミさんがすうっと現れる
    func appearFumi() async {
        sparkleBurst(around: CGPoint(x: fumi.position.x, y: fumi.position.y + 8), count: 8)
        await run(.fadeAlpha(to: 0.92, duration: 1.4), on: fumi)
        showFumiZone()
    }

    /// 迷子の子が泣きやんで笑顔になる
    func makeChildHappy() {
        animateGhost(child, frames: ["child_happy_0", "child_happy_1"])
    }

    /// 迷子の子が光に包まれて空へのぼっていく（成仏）
    func ascendChild() async {
        removeZones { $0 == .child }
        child.removeAction(forKey: "float")
        sparkleBurst(around: CGPoint(x: child.position.x, y: child.position.y + 8), count: 14)
        await run(.group([
            .moveBy(x: 0, y: 28, duration: 2.4),
            .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.8)]),
        ]), on: child)
        child.removeFromParent()
    }

    // MARK: - しおり

    func showBookmarkSparkle() {
        let frames = (0..<3).map { Self.texture("sparkle_\($0)") }
        bookmarkSparkle.texture = frames[0]
        bookmarkSparkle.size = CGSize(width: 8, height: 8)
        bookmarkSparkle.position = point(column: 3, row: 11.6)
        bookmarkSparkle.zPosition = 9_600
        bookmarkSparkle.run(.repeatForever(.animate(with: frames + [frames[1]], timePerFrame: 0.18)))
        if bookmarkSparkle.parent == nil {
            addToWorld(bookmarkSparkle)
        }
        addZone(column: 2.25, row: 11.0, width: 1.5, height: 1.6, interactable: .bookmark, anchor: (3, 10.4))
    }

    func removeBookmarkSparkle() {
        removeZones { $0 == .bookmark }
        bookmarkSparkle.removeFromParent()
    }

    /// すみの棚から、挟んだしおりの赤いひもが少しのぞく
    func showShelvedBookmark() {
        guard let cornerShelfNode, cornerShelfNode.childNode(withName: "bookmark") == nil else { return }
        let ribbon = SKSpriteNode(color: SKColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1), size: CGSize(width: 1, height: 4))
        ribbon.name = "bookmark"
        ribbon.anchorPoint = CGPoint(x: 0, y: 1)
        ribbon.position = CGPoint(x: 28, y: -10)
        ribbon.zPosition = 1
        cornerShelfNode.addChild(ribbon)
    }

    // MARK: - 演出

    /// まわりに小さな光の粒を散らす
    private func sparkleBurst(around center: CGPoint, count: Int) {
        let frames = (0..<3).map { Self.texture("sparkle_\($0)") }
        for index in 0..<count {
            let particle = SKSpriteNode(texture: frames[index % 3])
            particle.position = CGPoint(x: center.x + .random(in: -10...10), y: center.y + .random(in: -8...8))
            particle.zPosition = 9_700
            particle.alpha = 0
            particle.setScale(0.75)
            particle.run(.sequence([
                .wait(forDuration: Double(index) * 0.08),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .moveBy(x: .random(in: -4...4), y: .random(in: 14...26), duration: 1.4),
                    .animate(with: frames, timePerFrame: 0.15),
                    .sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.6)]),
                ]),
                .removeFromParent(),
            ]))
            addToWorld(particle)
        }
    }
}
