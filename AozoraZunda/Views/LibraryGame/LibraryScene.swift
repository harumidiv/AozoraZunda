import SpriteKit

/// 図書館の中で調べられるもの
enum LibraryInteractable: Equatable {
    /// かな行ごとの本棚（label は "あ"〜"わ"）
    case shelf(label: String)
    case librarian

    var prompt: String {
        switch self {
        case .shelf(let label):
            "「\(label)」の棚 ── \(label)行の作家の本が並んでいる"
        case .librarian:
            "司書さん ── 作品名や作家名で本をさがしてくれる"
        }
    }
}

/// 図書館のマップ。キャラクターを歩かせて本棚や司書さんを調べる
final class LibraryScene: SKScene {
    /// 移動入力（各成分 -1〜1。y は上が正）
    var moveInput: CGVector = .zero
    /// 調べられるものの前に立ったとき・離れたときに呼ばれる
    var onFocusChange: ((LibraryInteractable?) -> Void)?
    private(set) var focus: LibraryInteractable?

    private static let tile: CGFloat = 16
    private static let columns = 24
    private static let rows = 20
    private static let shelfLabels = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]
    private static let walkSpeed: CGFloat = 72

    private let world = SKNode()
    private let player = SKSpriteNode()
    private let playerCamera = SKCameraNode()
    private let bubble = SKSpriteNode()
    private var zones: [(rect: CGRect, interactable: LibraryInteractable, anchor: CGPoint)] = []
    private var isSetUp = false

    private enum Facing: String {
        case down, up, side
    }

    private var facing = Facing.down
    private var playerTextureName = ""
    private var walkTime: TimeInterval = 0
    private var lastUpdate: TimeInterval?

    override init(size: CGSize = CGSize(width: 390, height: 844)) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.17, green: 0.12, blue: 0.10, alpha: 1)
        physicsWorld.gravity = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard !isSetUp else { return }
        isSetUp = true
        addChild(world)
        buildRoom()
        buildFurniture()
        buildCharacters()
        camera = playerCamera
        playerCamera.setScale(1.0 / 3.0)
        addChild(playerCamera)
        updateCamera()
    }

    // MARK: - Map building

    /// マス座標（左上が 0,0。行は下に向かって増える）をシーン座標に変換する
    private static func point(column: CGFloat, row: CGFloat) -> CGPoint {
        CGPoint(x: column * tile, y: (CGFloat(rows) - row) * tile)
    }

    private static func texture(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: "sprite_\(name)")
        texture.filteringMode = .nearest
        return texture
    }

    /// 左上をマス座標に合わせてスプライトを置く
    @discardableResult
    private func place(_ name: String, column: CGFloat, row: CGFloat, z: CGFloat? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(texture: Self.texture(name))
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = Self.point(column: column, row: row)
        // 指定がなければ足元の高さで前後関係を決める（下にあるものほど手前）
        node.zPosition = z ?? Self.depth(forBaseY: node.position.y - node.size.height)
        world.addChild(node)
        return node
    }

    private static func depth(forBaseY y: CGFloat) -> CGFloat {
        1000 - y
    }

    /// 衝突判定用の見えない障害物。マス座標で指定する
    private func addObstacle(column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat) {
        let origin = Self.point(column: column, row: row + height)
        let size = CGSize(width: width * Self.tile, height: height * Self.tile)
        let node = SKNode()
        node.position = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        node.physicsBody = body
        world.addChild(node)
    }

    private func buildRoom() {
        for row in 2..<(Self.rows - 1) {
            for column in 1..<(Self.columns - 1) {
                let variant = (row * 7 + column * 3) % 3
                place("floor_\(variant)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for column in 1..<(Self.columns - 1) {
            place("wall_upper", column: CGFloat(column), row: 0, z: -9_000)
            place("wall_lower", column: CGFloat(column), row: 1, z: -9_000)
        }
        for row in 0..<Self.rows {
            place("wall_side", column: 0, row: CGFloat(row), z: -8_000)
            place("wall_side", column: CGFloat(Self.columns - 1), row: CGFloat(row), z: -8_000)
        }
        for column in 1..<(Self.columns - 1) {
            place("wall_side", column: CGFloat(column), row: CGFloat(Self.rows - 1), z: 5_000)
        }
        for column in [3, 8, 14, 19] {
            place("window", column: CGFloat(column), row: 0, z: -8_500)
        }
        place("clock", column: 11.5, row: 0.4, z: -8_500)

        addObstacle(column: 0, row: 0, width: CGFloat(Self.columns), height: 2.25)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(Self.rows))
        addObstacle(column: CGFloat(Self.columns - 1), row: 0, width: 1, height: CGFloat(Self.rows))
        addObstacle(column: 0, row: CGFloat(Self.rows - 1), width: CGFloat(Self.columns), height: 1)
    }

    private func buildFurniture() {
        place("rug", column: 10, row: 11, z: -9_500)
        place("doormat", column: 11, row: 18.2, z: -9_500)

        // 本棚: 上の列に6つ、下の列に4つ（中央の通路を空ける）
        let upperColumns: [CGFloat] = [2, 5, 8, 14, 17, 20]
        let lowerColumns: [CGFloat] = [5, 8, 14, 17]
        let shelfSlots = upperColumns.map { (column: $0, row: CGFloat(3)) }
            + lowerColumns.map { (column: $0, row: CGFloat(8)) }
        for (index, slot) in shelfSlots.enumerated() {
            let shelf = place("bookshelf_\(index % 4)", column: slot.column, row: slot.row)
            let sign = place("sign_\(index)", column: slot.column + 0.56, row: slot.row - 0.45)
            sign.zPosition = shelf.zPosition + 1
            addObstacle(column: slot.column, row: slot.row + 1, width: 2, height: 1)

            let label = Self.shelfLabels[index]
            let zoneOrigin = Self.point(column: slot.column - 0.25, row: slot.row + 3.1)
            zones.append((
                rect: CGRect(x: zoneOrigin.x, y: zoneOrigin.y, width: 2.5 * Self.tile, height: 1.2 * Self.tile),
                interactable: .shelf(label: label),
                anchor: Self.point(column: slot.column + 1, row: slot.row - 0.6)
            ))
        }

        // 受付カウンター
        place("counter", column: 2, row: 14)
        addObstacle(column: 2, row: 14.5, width: 3, height: 1)
        let counterZone = Self.point(column: 1.5, row: 17.2)
        zones.append((
            rect: CGRect(x: counterZone.x, y: counterZone.y, width: 4 * Self.tile, height: 1.8 * Self.tile),
            interactable: .librarian,
            anchor: Self.point(column: 3.5, row: 12.6)
        ))

        // 閲覧机と椅子
        for row in [CGFloat(13), 16] {
            place("table", column: 16, row: row)
            place("chair", column: 15, row: row + 0.3)
            place("chair", column: 18, row: row + 0.3)
            addObstacle(column: 15, row: row + 0.5, width: 4, height: 1)
        }

        // 観葉植物
        for (column, row) in [(1.0, 2.0), (22.0, 2.0), (1.0, 16.6), (22.0, 16.6), (20.0, 8.0), (11.0, 6.4)] {
            place("plant", column: column, row: row)
            addObstacle(column: column + 0.2, row: row + 1.1, width: 0.6, height: 0.4)
        }
    }

    private func buildCharacters() {
        let librarian = SKSpriteNode(texture: Self.texture("librarian_idle1"))
        librarian.anchorPoint = CGPoint(x: 0.5, y: 0)
        librarian.position = Self.point(column: 3.5, row: 14.3)
        librarian.zPosition = Self.depth(forBaseY: librarian.position.y)
        world.addChild(librarian)
        let blink = SKAction.sequence([
            .setTexture(Self.texture("librarian_idle1")),
            .wait(forDuration: 2.6, withRange: 1.2),
            .setTexture(Self.texture("librarian_idle2")),
            .wait(forDuration: 0.15),
        ])
        librarian.run(.repeatForever(blink))

        let shadow = SKSpriteNode(texture: Self.texture("shadow"))
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        shadow.position = CGPoint(x: 0, y: 1)
        shadow.zPosition = -1
        player.addChild(shadow)

        player.size = CGSize(width: 16, height: 16)
        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.position = Self.point(column: 12, row: 17.6)
        facing = .up
        // 足元だけに当たり判定を付ける
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 10, height: 6), center: CGPoint(x: 0, y: 3))
        body.allowsRotation = false
        body.friction = 0
        body.linearDamping = 0
        body.restitution = 0
        player.physicsBody = body
        world.addChild(player)

        bubble.texture = Self.texture("bubble")
        bubble.size = CGSize(width: 11, height: 11)
        bubble.anchorPoint = CGPoint(x: 0.5, y: 0)
        bubble.zPosition = 10_000
        bubble.isHidden = true
        bubble.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.4),
            .moveBy(x: 0, y: -2, duration: 0.4),
        ])))
        world.addChild(bubble)
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let delta = min(1.0 / 20, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime

        var input = moveInput
        let length = hypot(input.dx, input.dy)
        if length > 1 {
            input = CGVector(dx: input.dx / length, dy: input.dy / length)
        }
        let isMoving = length > 0.15
        player.physicsBody?.velocity = isMoving
            ? CGVector(dx: input.dx * Self.walkSpeed, dy: input.dy * Self.walkSpeed)
            : .zero

        if isMoving {
            if abs(input.dx) > abs(input.dy) {
                facing = .side
                player.xScale = input.dx < 0 ? -1 : 1
            } else {
                facing = input.dy > 0 ? .up : .down
                player.xScale = 1
            }
            walkTime += delta
        } else {
            walkTime = 0
        }
        updatePlayerTexture(isMoving: isMoving)
    }

    override func didSimulatePhysics() {
        player.zPosition = Self.depth(forBaseY: player.position.y)
        updateCamera()
        updateFocus()
    }

    private func updatePlayerTexture(isMoving: Bool) {
        let frame: String
        if isMoving {
            let frames = ["step1", "stand", "step2", "stand"]
            frame = frames[Int(walkTime / 0.13) % frames.count]
        } else {
            frame = "stand"
        }
        let name = "player_\(facing.rawValue)_\(frame)"
        if name != playerTextureName {
            playerTextureName = name
            player.texture = Self.texture(name)
        }
    }

    private func updateCamera() {
        guard let view else { return }
        let scale = playerCamera.xScale
        let visible = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        let mapSize = CGSize(width: CGFloat(Self.columns) * Self.tile, height: CGFloat(Self.rows) * Self.tile)

        func clamp(_ value: CGFloat, visible: CGFloat, map: CGFloat) -> CGFloat {
            guard visible < map else { return map / 2 }
            return min(max(value, visible / 2), map - visible / 2)
        }
        let target = CGPoint(x: player.position.x, y: player.position.y + 8)
        // 画面の1ドットに揃えてにじみを防ぐ
        let x = (clamp(target.x, visible: visible.width, map: mapSize.width) / scale).rounded() * scale
        let y = (clamp(target.y, visible: visible.height, map: mapSize.height) / scale).rounded() * scale
        playerCamera.position = CGPoint(x: x, y: y)
    }

    private func updateFocus() {
        let feet = player.position
        let zone = zones.first { $0.rect.contains(feet) }
        if let zone {
            bubble.isHidden = false
            if bubble.position.x != zone.anchor.x {
                bubble.removeAllActions()
                bubble.position = zone.anchor
                bubble.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 2, duration: 0.4),
                    .moveBy(x: 0, y: -2, duration: 0.4),
                ])))
            }
        } else {
            bubble.isHidden = true
        }
        let newFocus = zone?.interactable
        if newFocus != focus {
            focus = newFocus
            onFocusChange?(newFocus)
        }
    }
}
