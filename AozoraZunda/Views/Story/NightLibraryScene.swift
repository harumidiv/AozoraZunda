import SpriteKit

/// 夜間図書室で調べられるもの
enum NightLibraryInteractable: WalkInteractable {
    case fumi
    case child
    /// 第1章のお客さん。閲覧机にいる中学生の幽霊
    case taku
    /// タクが落としたしおり（切符）
    case takuBookmark
    /// 第2章のお客さん。閲覧机にいる猫の幽霊
    case tama
    /// 第3章のお客さん。手紙を持った少女の幽霊
    case sachi
    /// 第4章のお客さん。食いしん坊の兄弟
    case brothers
    /// カウンターの上の、貸出カードの箱
    case cardBox
    /// 本をかかえた小さな影（近づくと消える）
    case shadow
    /// 終章の少女の幽霊
    case haru
    /// エピローグの、つぎのお客さん
    case newcomer
    /// 上の列の本棚（3 は右奥の「すみの棚」）
    case bookshelf(Int)
    case pictureBookShelf
    /// 床に落ちているしおり
    case bookmark
    /// ストーリーには関係なく、図書室を歩き回っている幽霊
    case wanderer(NightWanderer)
    case exit

    static let cornerShelf = 3

    var prompt: String {
        switch self {
        case .fumi: "おフミさん ── むかしの司書さん。透けているのだ"
        case .child: "まいごの子 ── しくしく泣いているのだ"
        case .taku: "タク ── 閲覧机でボロボロの本を見つめているのだ"
        case .takuBookmark: "机の下で何か光っているのだ"
        case .tama: "タマ ── 閲覧机の上でまるくなっている、猫の幽霊なのだ"
        case .sachi: "サチ ── 封筒をぎゅっと胸にかかえているのだ"
        case .brothers: "タイチとジロ ── 食いしん坊の兄弟なのだ。弟のほうが、すごく薄いのだ"
        case .cardBox: "貸出カードの箱 ── 古いカードがぎっしりなのだ"
        case .shadow: "……"
        case .haru: "はる ── 赤い手袋をした、三つ編みの女の子なのだ"
        case .newcomer: "あたらしいお客さん ── 入口で、きょろきょろしているのだ"
        case .bookshelf(Self.cornerShelf): "すみの棚 ── 古い本がぎっしり並んでいるのだ"
        case .bookshelf: "本棚 ── むずかしそうな本がぎっしりなのだ"
        case .pictureBookShelf: "絵本の棚 ── 表紙が見えるように並んでいるのだ"
        case .bookmark: "床で何かが光っているのだ"
        case .wanderer(let wanderer): wanderer.prompt
        case .exit: "入口 ── ずんだもんの部屋に帰るのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .fumi, .child, .taku, .tama, .sachi, .brothers, .haru, .newcomer, .wanderer: "はなす"
        case .bookmark, .takuBookmark: "ひろう"
        case .exit: "かえる"
        default: "しらべる"
        }
    }

    var triggersOnEnter: Bool {
        self == .exit || self == .shadow
    }
}

/// 雨の夜だけ開く図書室のマップ。ストーリーの舞台
final class NightLibraryScene: WalkScene<NightLibraryInteractable> {
    private let flags: Set<StoryFlag>
    private let fumi = SKSpriteNode()
    private let child = SKSpriteNode()
    private let bookmarkSparkle = SKSpriteNode()
    private let taku = SKSpriteNode()
    private let takuBookmarkSparkle = SKSpriteNode()
    private let tama = SKSpriteNode()
    private let sachi = SKSpriteNode()
    private let taichi = SKSpriteNode()
    private let jiro = SKSpriteNode()
    private let shadowGirl = SKSpriteNode()
    private let haru = SKSpriteNode()
    private let newcomer = SKSpriteNode()
    private var nightOverlay: SKSpriteNode?
    private var windows: [SKSpriteNode] = []
    private var lampGlows: [SKSpriteNode] = []
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
        // ストーリーの幽霊を優先して話しかけられるよう、調べられる範囲はあとから足す
        buildWanderers()
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
            windows.append(window)
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
        // 第5章でしおりを抜き出すまでは、すみの棚から赤いひもがのぞいている
        if flags.contains(.prologueBookmarkShelved) && !flags.contains(.chapter5FoundGap) {
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

        // カウンターの上の、貸出カードの箱
        place("card_box", column: 8.9, row: 6.4)

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
        nightOverlay = night

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
            lampGlows.append(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 0.5),
                .fadeAlpha(to: 0.7, duration: 0.4),
            ])))
            addToWorld(glow)
        }
    }

    private func buildCharacters() {
        setUpGhost(fumi, frames: ["fumi_0", "fumi_1"], at: point(column: 8, row: 7.3))
        if flags.contains(.finaleFumiPassed) {
            fumi.removeFromParent()
        } else if flags.contains(.prologueMetFumi) {
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

        // 第1章: 閲覧机にタクがいる
        if flags.contains(.prologueCleared) && !flags.contains(.chapter1Cleared) {
            setUpGhost(taku, frames: ["taku_normal_0", "taku_normal_1"], at: point(column: 3, row: 7.1))
            addZone(column: 1.5, row: 8.3, width: 3, height: 1.3, interactable: .taku, anchor: (3, 5.7))
            if flags.contains(.chapter1AskedBookmark) && !flags.contains(.chapter1FoundBookmark) {
                showTakuBookmarkSparkle()
            }
        }

        // 第2章: 閲覧机の上に猫の幽霊タマがいる
        if flags.contains(.chapter1Cleared) && !flags.contains(.chapter2TamaPassed) {
            setUpGhost(tama, frames: ["tama_0", "tama_1"], at: point(column: 3, row: 7.4))
            addZone(column: 1.5, row: 8.3, width: 3, height: 1.3, interactable: .tama, anchor: (3, 6.0))
        }

        // 第3章: 閲覧机に、手紙を持った少女の幽霊サチがいる
        if flags.contains(.chapter2Cleared) && !flags.contains(.chapter3SachiPassed) {
            let frames = flags.contains(.chapter3LetterDelivered) ? ["sachi_happy_0", "sachi_happy_1"] : ["sachi_normal_0", "sachi_normal_1"]
            setUpGhost(sachi, frames: frames, at: point(column: 3, row: 7.1))
            addZone(column: 1.5, row: 8.3, width: 3, height: 1.3, interactable: .sachi, anchor: (3, 5.7))
        }

        // 第4章: 閲覧机に、食いしん坊の兄弟がいる（弟のジロは消えかけている）
        if flags.contains(.chapter3Cleared) && !flags.contains(.chapter4BrothersPassed) {
            setUpGhost(taichi, frames: ["brother_elder_0", "brother_elder_1"], at: point(column: 2.4, row: 7.1))
            setUpGhost(jiro, frames: ["brother_younger_0", "brother_younger_1"], at: point(column: 3.8, row: 7.1))
            if flags.contains(.chapter4Escaped) {
                makeBrothersClear()
            } else {
                jiro.alpha = 0.3
            }
            addZone(column: 1.5, row: 8.3, width: 3, height: 1.3, interactable: .brothers, anchor: (3.1, 5.7))
        }

        // 第5章から: カウンターの貸出カードの箱を調べられる
        if flags.contains(.chapter4Cleared) {
            addZone(column: 9.6, row: 7.4, width: 1.4, height: 1.0, interactable: .cardBox, anchor: (9.4, 5.9))
        }
        // 第5章: おフミさんに聞いたあと、すみの棚のそばに小さな影があらわれる
        if flags.contains(.chapter5AskedFumi) && !flags.contains(.chapter5SawShadow) {
            showShadow()
        }

        // 終章: 本の中から一緒に戻ってきたはる
        if flags.contains(.finaleFoundHaru) && !flags.contains(.finaleFumiPassed) {
            showHaru()
        }

        // エピローグのあと: 入口に、つぎのお客さん
        if flags.contains(.epilogueCleared) {
            showNewcomer(animated: false)
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

    // MARK: - タク

    /// タクのしおりが、カウンターのそばで光る
    func showTakuBookmarkSparkle() {
        showSparkle(takuBookmarkSparkle, at: point(column: 10.6, row: 9.4))
        addZone(column: 9.85, row: 8.9, width: 1.5, height: 1.6, interactable: .takuBookmark, anchor: (10.6, 8.6))
    }

    func removeTakuBookmarkSparkle() {
        removeZones { $0 == .takuBookmark }
        takuBookmarkSparkle.removeFromParent()
    }

    func makeTakuHappy() {
        animateGhost(taku, frames: ["taku_happy_0", "taku_happy_1"])
    }

    /// 結末を知ったタクが成仏する
    func ascendTaku() async {
        removeZones { $0 == .taku }
        taku.removeAction(forKey: "float")
        sparkleBurst(around: CGPoint(x: taku.position.x, y: taku.position.y + 8), count: 14)
        await run(.group([
            .moveBy(x: 0, y: 28, duration: 2.4),
            .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.8)]),
        ]), on: taku)
        taku.removeFromParent()
    }

    // MARK: - タマ

    /// ずんだもんの読み聞かせを聞いたタマが成仏する
    func ascendTama() async {
        removeZones { $0 == .tama }
        tama.removeAction(forKey: "float")
        sparkleBurst(around: CGPoint(x: tama.position.x, y: tama.position.y + 8), count: 14)
        await run(.group([
            .moveBy(x: 0, y: 28, duration: 2.4),
            .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.8)]),
        ]), on: tama)
        tama.removeFromParent()
    }

    // MARK: - サチ

    func makeSachiHappy() {
        animateGhost(sachi, frames: ["sachi_happy_0", "sachi_happy_1"])
    }

    /// 手紙を届けたサチが成仏する
    func ascendSachi() async {
        removeZones { $0 == .sachi }
        sachi.removeAction(forKey: "float")
        sparkleBurst(around: CGPoint(x: sachi.position.x, y: sachi.position.y + 8), count: 14)
        await run(.group([
            .moveBy(x: 0, y: 28, duration: 2.4),
            .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.8)]),
        ]), on: sachi)
        sachi.removeFromParent()
    }

    // MARK: - タイチとジロ

    /// 読み合わせを終えて、ジロの姿がはっきりする
    func makeBrothersClear() {
        jiro.alpha = 0.92
    }

    /// 兄弟がそろって成仏する
    func ascendBrothers() async {
        removeZones { $0 == .brothers }
        for ghost in [taichi, jiro] {
            ghost.removeAction(forKey: "float")
            sparkleBurst(around: CGPoint(x: ghost.position.x, y: ghost.position.y + 8), count: 10)
            ghost.run(.group([
                .moveBy(x: 0, y: 28, duration: 2.4),
                .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 1.8)]),
            ]), withKey: "ascend")
        }
        await run(.wait(forDuration: 2.5), on: self)
        taichi.removeFromParent()
        jiro.removeFromParent()
    }

    // MARK: - 消えた本

    /// 本をかかえた小さな影が、すみの棚のそばにあらわれる
    func showShadow() {
        guard shadowGirl.parent == nil else { return }
        setUpGhost(shadowGirl, frames: ["haru_shadow_0", "haru_shadow_1"], at: point(column: 13, row: 8.6))
        shadowGirl.childNode(withName: "halo")?.removeFromParent()
        shadowGirl.childNode(withName: "shine")?.alpha = 0.3
        shadowGirl.alpha = 0
        shadowGirl.run(.fadeAlpha(to: 0.75, duration: 1.2))
        addZone(column: 12.2, row: 8.0, width: 1.6, height: 1.2, interactable: .shadow, anchor: (13, 7.0))
    }

    /// 近づくと、影はふっと消える
    func vanishShadow() async {
        removeZones { $0 == .shadow }
        shadowGirl.removeAction(forKey: "float")
        await run(.group([.fadeOut(withDuration: 0.5), .moveBy(x: 6, y: 0, duration: 0.5)]), on: shadowGirl)
        shadowGirl.removeFromParent()
    }

    // MARK: - はる

    func showHaru() {
        guard haru.parent == nil else { return }
        setUpGhost(haru, frames: ["haru_normal_0", "haru_normal_1"], at: point(column: 5.2, row: 9.6))
        addZone(column: 4.2, row: 9.7, width: 1.8, height: 1.3, interactable: .haru, anchor: (5.2, 8.2))
    }

    func makeHaruHappy() {
        animateGhost(haru, frames: ["haru_happy_0", "haru_happy_1"])
    }

    /// はるがおフミさんのとなりへ行く
    func walkHaruToFumi() async {
        removeZones { $0 == .haru }
        await run(.move(to: point(column: 6.6, row: 9.2), duration: 1.2), on: haru)
        haru.zPosition = Self.depth(forBaseY: haru.position.y)
    }

    /// おフミさんとはるが、一緒に成仏する
    func ascendFumiAndHaru() async {
        removeZones { $0 == .fumi || $0 == .haru }
        for ghost in [fumi, haru] {
            ghost.removeAction(forKey: "float")
            sparkleBurst(around: CGPoint(x: ghost.position.x, y: ghost.position.y + 8), count: 16)
            ghost.run(.group([
                .moveBy(x: 0, y: 36, duration: 3.2),
                .sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 2.2)]),
            ]), withKey: "ascend")
        }
        await run(.wait(forDuration: 3.3), on: self)
        fumi.removeFromParent()
        haru.removeFromParent()
    }

    // MARK: - エピローグ

    /// 雨がやんで、朝になる。歩き回っていた幽霊たちも、どこかへ帰っていく
    func makeMorning() {
        nightOverlay?.color = SKColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        for window in windows {
            window.removeAllActions()
            window.texture = Self.texture("sun_window")
        }
        for glow in lampGlows {
            glow.removeAllActions()
            glow.alpha = 0.2
        }
        for walker in walkers {
            walker.body.removeFromParent()
        }
        walkers = []
        removeZones { if case .wanderer = $0 { return true } else { return false } }
    }

    /// 入口に、つぎのお客さんが立っている
    func showNewcomer(animated: Bool) {
        guard newcomer.parent == nil else { return }
        setUpGhost(newcomer, frames: ["newcomer_0", "newcomer_1"], at: point(column: 10.4, row: 12.1))
        addZone(column: 9.6, row: 11.4, width: 1.6, height: 1.3, interactable: .newcomer, anchor: (10.4, 10.7))
        if animated {
            newcomer.alpha = 0
            newcomer.run(.fadeAlpha(to: 0.92, duration: 1.6))
        }
    }

    // MARK: - 歩き回る幽霊

    private func buildWanderers() {
        for wanderer in NightWanderer.allCases where flags.contains(wanderer.appearsAfter) {
            let route = wanderer.route.map { point(column: $0.column, row: $0.row) }
            guard let start = route.first else { continue }

            // 入れ物ごと道を歩かせ、中の絵はその場でふわふわ浮かせる（動きが重ならないように分ける）
            let body = SKNode()
            body.position = start
            let ghost = SKSpriteNode()
            setUpGhost(ghost, frames: wanderer.frames, at: .zero)
            ghost.removeFromParent()
            ghost.zPosition = 0
            if wanderer == .wisp {
                ghost.alpha = 0.8
                ghost.childNode(withName: "shine")?.alpha = 0.3
            }
            body.addChild(ghost)
            addToWorld(body)
            addZone(following: body, width: 2.2, height: 1.4, interactable: .wanderer(wanderer))

            walkers.append(Walker(wanderer: wanderer, body: body, ghost: ghost, route: route))
        }
    }

    /// 歩き回る幽霊の、道のどこまで来たか
    private struct Walker {
        let wanderer: NightWanderer
        let body: SKNode
        let ghost: SKSpriteNode
        let route: [CGPoint]
        /// いま向かっている曲がり角
        var target = 1
        /// 曲がり角で立ち止まっている残り時間
        var resting: TimeInterval = 0
    }

    private var walkers: [Walker] = []
    private var lastWanderTime: TimeInterval?

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let delta = min(1.0 / 20, currentTime - (lastWanderTime ?? currentTime))
        lastWanderTime = currentTime
        for index in walkers.indices {
            moveWalker(&walkers[index], delta: delta)
        }
    }

    private func moveWalker(_ walker: inout Walker, delta: TimeInterval) {
        // ずんだもんが前に立っている間は、立ち止まって話を聞いてくれる
        guard focus != .wanderer(walker.wanderer), walker.route.count > 1 else { return }
        if walker.resting > 0 {
            walker.resting -= delta
            return
        }
        let position = walker.body.position
        let goal = walker.route[walker.target]
        let dx = goal.x - position.x, dy = goal.y - position.y
        let distance = hypot(dx, dy)
        let step = CGFloat(delta) * Self.tile / walker.wanderer.secondsPerTile
        if distance <= step {
            walker.body.position = goal
            walker.target = (walker.target + 1) % walker.route.count
            walker.resting = .random(in: walker.wanderer.pause)
        } else {
            walker.body.position = CGPoint(x: position.x + dx / distance * step, y: position.y + dy / distance * step)
            // 進む向きに合わせて左右を向く
            if abs(dx) > 0.5 {
                walker.ghost.xScale = dx < 0 ? -1 : 1
            }
        }
    }

    override func didSimulatePhysics() {
        super.didSimulatePhysics()
        for walker in walkers {
            walker.body.zPosition = Self.depth(forBaseY: walker.body.position.y)
        }
    }

    // MARK: - しおり

    /// 床に落ちている物のきらめき
    private func showSparkle(_ sparkle: SKSpriteNode, at position: CGPoint) {
        let frames = (0..<3).map { Self.texture("sparkle_\($0)") }
        sparkle.texture = frames[0]
        sparkle.size = CGSize(width: 8, height: 8)
        sparkle.position = position
        sparkle.zPosition = 9_600
        sparkle.run(.repeatForever(.animate(with: frames + [frames[1]], timePerFrame: 0.18)))
        if sparkle.parent == nil {
            addToWorld(sparkle)
        }
    }

    func showBookmarkSparkle() {
        showSparkle(bookmarkSparkle, at: point(column: 3, row: 11.6))
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

    /// すみの棚から、しおりを抜き出す
    func removeShelvedBookmark() {
        cornerShelfNode?.childNode(withName: "bookmark")?.removeFromParent()
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
