import SpriteKit

/// 歩いて近づくと調べられるもの
protocol WalkInteractable: Equatable {
    /// 前に立ったときにメッセージウインドウに出す説明
    var prompt: String { get }
    /// 調べるボタンの文言
    var actionTitle: String { get }
}

/// キャラクターを歩かせて、調べられるものの前で吹き出しを出すマップの共通部分。
/// サブクラスは `buildMap()` で床・壁・家具・調べられる場所を作る
class WalkScene<Interactable: WalkInteractable>: SKScene {
    /// 移動入力（各成分 -1〜1。y は上が正）
    var moveInput: CGVector = .zero
    /// 調べられるものの前に立ったとき・離れたときに呼ばれる
    var onFocusChange: ((Interactable?) -> Void)?
    private(set) var focus: Interactable?

    static var tile: CGFloat { 16 }
    let columns: Int
    let rows: Int
    private let playerStart: (column: CGFloat, row: CGFloat)
    private static var walkSpeed: CGFloat { 72 }

    private let world = SKNode()
    private let player = SKSpriteNode()
    private let playerCamera = SKCameraNode()
    private let bubble = SKSpriteNode()
    private var zones: [(rect: CGRect, interactable: Interactable, anchor: CGPoint)] = []
    private var isSetUp = false

    private enum Facing: String {
        case down, up, side
    }

    private var facing = Facing.up
    private var playerTextureName = ""
    private var walkTime: TimeInterval = 0
    private var lastUpdate: TimeInterval?

    init(columns: Int, rows: Int, playerStart: (column: CGFloat, row: CGFloat), size: CGSize = CGSize(width: 390, height: 844)) {
        self.columns = columns
        self.rows = rows
        self.playerStart = playerStart
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
        buildMap()
        buildPlayer()
        camera = playerCamera
        playerCamera.setScale(1.0 / 3.0)
        addChild(playerCamera)
        updateCamera()
    }

    /// サブクラスで床・壁・家具・調べられる場所を作る
    func buildMap() {}

    // MARK: - Map building

    /// マス座標（左上が 0,0。行は下に向かって増える）をシーン座標に変換する
    func point(column: CGFloat, row: CGFloat) -> CGPoint {
        CGPoint(x: column * Self.tile, y: (CGFloat(rows) - row) * Self.tile)
    }

    static func texture(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: "sprite_\(name)")
        texture.filteringMode = .nearest
        return texture
    }

    /// 左上をマス座標に合わせてスプライトを置く
    @discardableResult
    func place(_ name: String, column: CGFloat, row: CGFloat, z: CGFloat? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(texture: Self.texture(name))
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = point(column: column, row: row)
        // 指定がなければ足元の高さで前後関係を決める（下にあるものほど手前）
        node.zPosition = z ?? Self.depth(forBaseY: node.position.y - node.size.height)
        world.addChild(node)
        return node
    }

    /// 足元の高さで決める前後関係
    static func depth(forBaseY y: CGFloat) -> CGFloat {
        1000 - y
    }

    /// 地図にノードを追加する（キャラクターなど place で置けないもの用）
    func addToWorld(_ node: SKNode) {
        world.addChild(node)
    }

    /// 衝突判定用の見えない障害物。マス座標で指定する
    func addObstacle(column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat) {
        let origin = point(column: column, row: row + height)
        let size = CGSize(width: width * Self.tile, height: height * Self.tile)
        let node = SKNode()
        node.position = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        node.physicsBody = body
        world.addChild(node)
    }

    /// 足元がこの範囲（マス座標の左上と大きさ）に入ると調べられる。吹き出しは anchor に出す
    func addZone(column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat, interactable: Interactable, anchor: (column: CGFloat, row: CGFloat)) {
        let origin = point(column: column, row: row + height)
        zones.append((
            rect: CGRect(x: origin.x, y: origin.y, width: width * Self.tile, height: height * Self.tile),
            interactable: interactable,
            anchor: point(column: anchor.column, row: anchor.row)
        ))
    }

    /// 調べられる場所の中身を差し替える（本の冊数で本棚の説明を変えるときなど）
    func replaceInteractable(where matches: (Interactable) -> Bool, with interactable: Interactable) {
        for index in zones.indices where matches(zones[index].interactable) {
            zones[index].interactable = interactable
        }
        if let focus, matches(focus), focus != interactable {
            self.focus = interactable
            onFocusChange?(interactable)
        }
    }

    private func buildPlayer() {
        let shadow = SKSpriteNode(texture: Self.texture("shadow"))
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        shadow.position = CGPoint(x: 0, y: 1)
        shadow.zPosition = -1
        player.addChild(shadow)

        player.size = CGSize(width: 16, height: 16)
        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.position = point(column: playerStart.column, row: playerStart.row)
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
        let mapSize = CGSize(width: CGFloat(columns) * Self.tile, height: CGFloat(rows) * Self.tile)

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
