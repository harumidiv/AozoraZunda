import SpriteKit

/// 『手袋を買いに』の本の中で調べられるもの
enum TebukuroInteractable: WalkInteractable, Hashable {
    /// 洞穴の前の、狐の親子
    case foxes
    /// 雪の上の、小さな人間の子の足あと
    case footprints(Int)
    /// 野原の先で、影がちらっと見える場所
    case glimpse
    /// 町の看板（0: 自転車、1: 眼鏡）
    case sign(Int)
    /// 黒い大きなシルクハットの看板の、帽子屋
    case hatShop
    /// やさしい唄声が聞こえる窓
    case lullabyWindow
    case haru

    var prompt: String {
        switch self {
        case .foxes: "狐の親子 ── 銀色の毛なみの、母さん狐と子狐なのだ"
        case .footprints: "足あと ── 雪の上に、小さな足あとがつづいているのだ"
        case .glimpse: ""
        case .sign(0): "看板 ── 自転車の絵なのだ"
        case .sign: "看板 ── 眼鏡の絵なのだ。ペンキがはげかけているのだ"
        case .hatShop: "帽子屋 ── 黒い大きなシルクハットの看板なのだ"
        case .lullabyWindow: "窓 ── 暖かそうな光と、やさしい声なのだ"
        case .haru: "女の子 ── 窓の下で、雪の上にうずくまっているのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .foxes, .haru: "はなす"
        case .hatShop: "たたく"
        case .lullabyWindow: "きく"
        default: "しらべる"
        }
    }

    var triggersOnEnter: Bool {
        self == .glimpse
    }
}

/// 『手袋を買いに』の本の中。狐の親子の住む雪の森から、雪あかりの野原を抜けて、夜の町へ。
/// 町の窓の下に、本をかかえたまま閉じこもっていた少女・はるがいる
final class TebukuroScene: WalkScene<TebukuroInteractable> {
    private let flags: Set<StoryFlag>
    private let haru = SKSpriteNode()
    private let fleeingShadow = SKSpriteNode()
    private var hatDoor: SKSpriteNode?
    private var lightBand: SKSpriteNode?

    init(flags: Set<StoryFlag>) {
        self.flags = flags
        // 手袋を買ったあとに入り直したときは、町の入口から
        let start: (CGFloat, CGFloat) = flags.contains(.finaleGotMittens) ? (6.5, 9.4) : (6.5, 37.4)
        super.init(columns: 14, rows: 40, playerStart: start)
        backgroundColor = SKColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1)
    }

    override func buildMap() {
        buildGround()
        buildForest()
        buildField()
        buildTown()
        buildLighting()
    }

    // MARK: - Map

    private func buildGround() {
        for row in 0..<rows {
            for column in 0..<columns {
                let isPath = (6...7).contains(column) && row >= 5
                let isStreet = (5...11).contains(row)
                let name = isPath || isStreet ? "snow_path" : "snow_\((row * 7 + column * 3) % 3)"
                place(name, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        addObstacle(column: 0, row: 0, width: 0.5, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns) - 0.5, row: 0, width: 0.5, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows) - 0.5, width: CGFloat(columns), height: 0.5)
    }

    private func fir(_ column: CGFloat, _ row: CGFloat) {
        place("snow_fir", column: column, row: row)
        addObstacle(column: column + 0.7, row: row + 1.5, width: 0.6, height: 0.5)
    }

    private func buildForest() {
        for (column, row) in [
            (0.0, 27.0), (11.5, 27.5), (0, 33), (12, 31), (9.5, 34.5), (0.5, 36.5), (11.8, 37.0), (2.8, 37.6),
            (9.8, 29.2), (3.2, 26.4),
        ] {
            fir(column, row)
        }
        // 狐の親子の洞穴
        place("fox_den", column: 1.2, row: 29.6)
        addObstacle(column: 1.4, row: 30.6, width: 1.6, height: 0.9)
        let mother = place("fox_mother", column: 3.4, row: 31.0)
        mother.xScale = -1
        mother.position.x += 16
        let child = place("fox_child", column: 4.4, row: 31.2)
        child.xScale = -1
        child.position.x += 16
        child.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.25), .moveBy(x: 0, y: -2, duration: 0.25), .wait(forDuration: 1.5)])))
        addObstacle(column: 3.5, row: 31.6, width: 1.8, height: 0.4)
        addZone(column: 3.0, row: 32.0, width: 3.2, height: 1.4, interactable: .foxes, anchor: (4.4, 30.4))
    }

    private func buildField() {
        for (column, row) in [(1.0, 18.0), (11.4, 20.0), (0.4, 23.2), (12.0, 14.6), (2.0, 13.0)] {
            fir(column, row)
        }
        let spots: [(CGFloat, CGFloat)] = [(6.4, 26.0), (6.9, 21.0), (6.5, 15.6)]
        for (index, spot) in spots.enumerated() {
            for offset: CGFloat in [-0.9, 0, 0.9] {
                place("snow_footprints", column: spot.0, row: spot.1 + offset, z: -9_800)
            }
            addZone(column: spot.0 - 0.6, row: spot.1, width: 2.2, height: 1.2, interactable: .footprints(index), anchor: (spot.0 + 0.5, spot.1 - 0.9))
        }
        if !flags.contains(.finaleGotMittens) {
            addZone(column: 4.5, row: 17.8, width: 5, height: 0.8, interactable: .glimpse, anchor: (7, 16.8))
        }
    }

    private func buildTown() {
        for column in 0..<columns {
            place("snowtown_roof", column: CGFloat(column), row: 0, z: -9_000)
        }
        // 家々の壁。窓はもう閉まっていて、高い窓から暖かそうな光が落ちている
        let walls: [Int: [String]] = [
            1: ["window", "plain", "dark", "plain", "window", "plain", "plain", "dark", "plain", "window", "plain", "dark", "window", "plain"],
            2: ["plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain", "plain"],
            3: ["plain", "dark", "plain", "plain", "plain", "dark", "plain", "plain", "plain", "plain", "plain", "plain", "window", "plain"],
            4: ["plain", "plain", "door", "plain", "plain", "door", "plain", "plain", "plain", "door", "plain", "plain", "plain", "plain"],
        ]
        for (row, kinds) in walls {
            for (column, kind) in kinds.enumerated() {
                let node = place("snowtown_wall_\(kind)", column: CGFloat(column), row: CGFloat(row), z: -9_000)
                if row == 4 && column == 9 {
                    hatDoor = node
                }
            }
        }
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 5)
        // 看板（小さな電燈がともっている）
        place("snowtown_sign_bicycle", column: 1.5, row: 2.2, z: -8_500)
        place("snowtown_sign_glasses", column: 4.5, row: 2.2, z: -8_500)
        place("snowtown_sign_hat", column: 8.5, row: 2.2, z: -8_500)
        addZone(column: 1.5, row: 5.0, width: 2, height: 1.3, interactable: .sign(0), anchor: (2.5, 1.6))
        addZone(column: 4.5, row: 5.0, width: 2, height: 1.3, interactable: .sign(1), anchor: (5.5, 1.6))
        addZone(column: 8.5, row: 5.0, width: 1.8, height: 1.3, interactable: .hatShop, anchor: (9.5, 1.6))
        addZone(column: 11.4, row: 5.0, width: 1.8, height: 1.0, interactable: .lullabyWindow, anchor: (12.5, 2.4))
        for column: CGFloat in [3.5, 10.5] {
            let lamp = place("street_lamp_0", column: column, row: 4.6)
            lamp.run(.repeatForever(.animate(with: [Self.texture("street_lamp_0"), Self.texture("street_lamp_1")], timePerFrame: 0.6)))
            addObstacle(column: column + 0.35, row: 6.3, width: 0.3, height: 0.3)
        }
        // 窓の下のはる
        let frames = flags.contains(.finaleGotMittens) && flags.contains(.finaleFoundHaru)
            ? ["haru_normal_0", "haru_normal_1"] : ["haru_sad_0", "haru_sad_1"]
        setUpHaru(frames: frames)
        haru.position = point(column: 12.6, row: 7.2)
        haru.zPosition = Self.depth(forBaseY: haru.position.y)
        addObstacle(column: 12.2, row: 6.8, width: 0.8, height: 0.4)
        addZone(column: 11.6, row: 7.0, width: 2.2, height: 1.3, interactable: .haru, anchor: (12.6, 5.6))
    }

    private func setUpHaru(frames: [String]) {
        haru.texture = Self.texture(frames[0])
        haru.size = CGSize(width: 16, height: 16)
        haru.anchorPoint = CGPoint(x: 0.5, y: 0)
        haru.alpha = 0.85
        haru.run(.repeatForever(.animate(with: frames.map { Self.texture($0) }, timePerFrame: 0.45)), withKey: "frames")
        if haru.parent == nil {
            addToWorld(haru)
        }
    }

    /// 雪あかりの夜。町の窓と街灯のまわりだけ暖かく光る
    private func buildLighting() {
        let night = SKSpriteNode(color: SKColor(red: 0.60, green: 0.66, blue: 0.92, alpha: 1), size: CGSize(width: 4_000, height: 4_000))
        night.blendMode = .multiply
        night.zPosition = 9_000
        addToCamera(night)
        let lights: [(CGFloat, CGFloat, CGFloat)] = [
            (4.0, 4.8, 1.4), (11.0, 4.8, 1.4), (12.5, 3.5, 1.1), (0.5, 1.5, 0.8), (4.5, 1.5, 0.8), (9.5, 1.5, 0.8),
            (2.5, 2.0, 0.7), (5.5, 2.0, 0.7), (9.5, 2.0, 0.9),
        ]
        for (column, row, scale) in lights {
            let glow = SKSpriteNode(texture: Self.texture("glow_warm"))
            glow.position = point(column: column, row: row)
            glow.blendMode = .add
            glow.zPosition = 9_500
            glow.setScale(scale)
            glow.alpha = 0.6
            addToWorld(glow)
        }
    }

    // MARK: - イベント

    /// 野原の先に、本をかかえた小さな影が見えて、町のほうへ逃げていく
    func glimpseShadow() async {
        removeZones { $0 == .glimpse }
        fleeingShadow.texture = Self.texture("haru_shadow_0")
        fleeingShadow.size = CGSize(width: 16, height: 16)
        fleeingShadow.anchorPoint = CGPoint(x: 0.5, y: 0)
        fleeingShadow.position = point(column: 7, row: 13.2)
        fleeingShadow.zPosition = 2_000
        fleeingShadow.alpha = 0
        fleeingShadow.run(.repeatForever(.animate(with: [Self.texture("haru_shadow_0"), Self.texture("haru_shadow_1")], timePerFrame: 0.2)), withKey: "frames")
        addToWorld(fleeingShadow)
        await run(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.4),
            .wait(forDuration: 0.5),
            .group([.moveBy(x: 0, y: 64, duration: 1.4), .sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.6)])]),
        ]), on: fleeingShadow)
        fleeingShadow.removeFromParent()
    }

    /// 帽子屋の戸が一寸ほどあいて、光の帯が雪の上に伸びる
    func openHatShopDoor(_ isOpen: Bool) {
        hatDoor?.texture = Self.texture(isOpen ? "snowtown_wall_ajar" : "snowtown_wall_door")
        if isOpen {
            let band = SKSpriteNode(color: SKColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 0.55), size: CGSize(width: 5, height: 40))
            band.anchorPoint = CGPoint(x: 0.5, y: 1)
            band.position = point(column: 9.7, row: 5)
            band.zRotation = 0.35
            band.blendMode = .add
            band.zPosition = 9_600
            addToWorld(band)
            lightBand = band
        } else {
            lightBand?.removeFromParent()
            lightBand = nil
        }
    }

    /// はるが手袋をはめる
    func giveMittensToHaru() {
        haru.removeAction(forKey: "frames")
        setUpHaru(frames: ["haru_normal_0", "haru_normal_1"])
    }

    func makeHaruHappy() {
        haru.removeAction(forKey: "frames")
        setUpHaru(frames: ["haru_happy_0", "haru_happy_1"])
    }
}
