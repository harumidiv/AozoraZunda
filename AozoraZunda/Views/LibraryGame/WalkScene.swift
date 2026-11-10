import SpriteKit

/// 歩いて近づくと調べられるもの
protocol WalkInteractable: Equatable {
    /// 前に立ったときにメッセージウインドウに出す説明
    var prompt: String { get }
    /// 調べるボタンの文言
    var actionTitle: String { get }
    /// true なら、ボタンを押さなくても入っただけで調べたことにする（出入口など）
    var triggersOnEnter: Bool { get }
}

extension WalkInteractable {
    var triggersOnEnter: Bool { false }
}

/// キャラクターを歩かせて、調べられるものの前で吹き出しを出すマップの共通部分。
/// サブクラスは `buildMap()` で床・壁・家具・調べられる場所を作る
class WalkScene<Interactable: WalkInteractable>: SKScene {
    /// 移動入力（各成分 -1〜1。y は上が正）。キーボード操作用。入力があるとタップでの移動は取りやめる
    var moveInput: CGVector = .zero
    /// 指が触れている位置（ビュー座標）。触れている間はその場所に向かって歩き続け、離すと最後に触れた場所まで歩く
    var touchPoint: CGPoint? {
        didSet {
            if oldValue == nil {
                // 新しくタップしたときは、同じ場所でも歩き直す
                destinationCell = nil
            }
            updateDestinationFromTouch()
        }
    }
    /// 調べられるものの前に立ったとき・離れたときに呼ばれる
    var onFocusChange: ((Interactable?) -> Void)?
    private(set) var focus: Interactable?
    /// 調べるとストーリーが進むものか。true のものには、ふつうとは別の金色の吹き出しを出す
    var isStoryTarget: ((Interactable) -> Bool)?
    /// いま調べられるか。false のものは吹き出しを出さず、調べられないようにする（開けたあとの扉など）
    var isAvailable: ((Interactable) -> Bool)?
    private var bubbleTextureName = "bubble"
    /// プレイヤーの絵の名前の頭につける文字（本の中で猫になるときなどに変える）
    var playerSpritePrefix = "player"
    /// 画面下でホームインジケーターなどに隠れる高さ（画面上のポイント）。マップの下端がその上に来るまでカメラを動かせる
    var bottomInset: CGFloat = 0

    static var tile: CGFloat { 16 }
    let columns: Int
    let rows: Int
    private let playerStart: (column: CGFloat, row: CGFloat)
    private static var walkSpeed: CGFloat { 72 }
    /// タップした場所へ向かうときの速さ（距離に関係なく一定）。1秒で約20マス
    private static var tapWalkSpeed: CGFloat { 320 }

    private let world = SKNode()
    private let player = SKSpriteNode()
    private let playerCamera = SKCameraNode()
    private let bubble = SKSpriteNode()
    private let destinationMarker = SKShapeNode(ellipseOf: CGSize(width: 10, height: 5))
    private var zones: [Zone] = []

    /// 調べられる範囲。follow があれば、そのノードと一緒に動く（歩き回る幽霊など）
    private struct Zone {
        var rect: CGRect
        var interactable: Interactable
        var anchor: CGPoint
        var follow: (node: SKNode, anchorRise: CGFloat)?

        /// ついていくノードの足元に合わせて、範囲と吹き出しの位置を動かす
        mutating func track() {
            // ノードは addToWorld で地図に直接置いたもの（地図の座標 = シーン座標）
            guard let follow else { return }
            let position = follow.node.position
            rect.origin = CGPoint(x: position.x - rect.width / 2, y: position.y - rect.height + 3)
            anchor = CGPoint(x: position.x, y: position.y + follow.anchorRise)
        }

        /// 調べる相手の足元のあたり。吹き出しは頭の上に出ているので、それより少し下とみなす
        var target: CGPoint {
            follow?.node.position ?? CGPoint(x: anchor.x, y: anchor.y - 20)
        }

        /// 前の範囲のほかに、相手の上下左右どこに立っても話しかけられる範囲
        var aroundTarget: CGRect {
            let target = target
            return CGRect(x: target.x - 22, y: target.y - 20, width: 44, height: 40)
        }
    }
    private var isSetUp = false

    // MARK: Tap-to-walk

    /// 経路探索に使う格子の1マスの大きさ（ドット）
    private static var navCell: CGFloat { 4 }
    /// 障害物（番号つき。扉のようにあとで取り除けるもの用）
    private var obstacles: [Int: (node: SKNode, rect: CGRect)] = [:]
    private var nextObstacleID = 0
    /// 格子の各マスにキャラクターが立てるか。障害物が変わったら作り直す
    private var walkableGrid: [Bool]?
    /// これから通る地点（シーン座標）。先頭から順に歩く
    private var path: [CGPoint] = []
    /// いま向かっている目的地の格子。同じ目的地なら経路を探し直さない
    private var destinationCell: GridCell?
    /// 経路に沿って歩いているのに進めていない時間。引っかかったら諦める
    private var stuckTime: TimeInterval = 0
    /// タップした場所へ歩く速さ（ドット/秒）。経路の長さから決める
    private var pathSpeed: CGFloat = 72

    // MARK: Party

    /// うしろをついて歩く仲間。昔の RPG の隊列のように、プレイヤーが通った道をなぞる
    private var followers: [SKNode] = []
    /// プレイヤーが通った地点（新しい順）
    private var trail: [CGPoint] = []
    private static var followerSpacing: CGFloat { 13 }

    private struct GridCell: Hashable {
        var x: Int
        var y: Int
    }

    private enum Facing: String {
        case down, up, side
    }

    private var facing = Facing.up
    /// いま前に立っている調べられるものの足元のあたり。止まったときにそちらを向く
    private var focusTarget: CGPoint?
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
        // マップを作るときに決めた仲間を、プレイヤーの位置にそろえる
        resetTrail()
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
    /// 取り除くときに使う番号を返す
    @discardableResult
    func addObstacle(column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat) -> Int {
        let origin = point(column: column, row: row + height)
        let size = CGSize(width: width * Self.tile, height: height * Self.tile)
        let node = SKNode()
        node.position = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        node.physicsBody = body
        world.addChild(node)
        let id = nextObstacleID
        nextObstacleID += 1
        obstacles[id] = (node, CGRect(origin: origin, size: size))
        walkableGrid = nil
        return id
    }

    /// 障害物を取り除く（扉が開いたときなど）
    func removeObstacle(_ id: Int) {
        obstacles[id]?.node.removeFromParent()
        obstacles[id] = nil
        walkableGrid = nil
    }

    /// プレイヤーに小物を持たせる（抱えた手紙など）。プレイヤーと一緒に動く
    func attachToPlayer(_ node: SKNode) {
        node.removeFromParent()
        player.addChild(node)
    }

    /// 足元がこの範囲（マス座標の左上と大きさ）に入ると調べられる。吹き出しは anchor に出す
    func addZone(column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat, interactable: Interactable, anchor: (column: CGFloat, row: CGFloat)) {
        let origin = point(column: column, row: row + height)
        zones.append(Zone(
            rect: CGRect(x: origin.x, y: origin.y, width: width * Self.tile, height: height * Self.tile),
            interactable: interactable,
            anchor: point(column: anchor.column, row: anchor.row)
        ))
    }

    /// 地図の上を動くノード（歩き回るキャラクター）の足元に、一緒に動く調べられる範囲を付ける。
    /// 大きさはマス単位、吹き出しは足元から anchorRise ドット上に出す
    func addZone(following node: SKNode, width: CGFloat, height: CGFloat, interactable: Interactable, anchorRise: CGFloat = 26) {
        var zone = Zone(
            rect: CGRect(x: 0, y: 0, width: width * Self.tile, height: height * Self.tile),
            interactable: interactable,
            anchor: .zero,
            follow: (node, anchorRise)
        )
        zone.track()
        zones.append(zone)
    }

    /// 調べられる場所を取り除く（成仏した幽霊など）。いま前に立っていれば吹き出しも消す
    func removeZones(where matches: (Interactable) -> Bool) {
        zones.removeAll { matches($0.interactable) }
        if let focus, matches(focus) {
            self.focus = nil
            bubble.isHidden = true
            onFocusChange?(nil)
        }
    }

    /// カメラに付けるノードを追加する（画面全体を暗くする夜の色など、マップと一緒に動かないもの）
    func addToCamera(_ node: SKNode) {
        playerCamera.addChild(node)
    }

    /// アクションを実行し、終わるまで待つ（イベントの演出用）
    func run(_ action: SKAction, on node: SKNode) async {
        await withCheckedContinuation { continuation in
            node.run(action) { continuation.resume() }
        }
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

        // タップした目的地の印（床の上・家具の下に描く）
        destinationMarker.strokeColor = SKColor(white: 1, alpha: 0.85)
        destinationMarker.fillColor = SKColor(white: 1, alpha: 0.2)
        destinationMarker.lineWidth = 1
        destinationMarker.isAntialiased = false
        destinationMarker.zPosition = -9_400
        destinationMarker.isHidden = true
        destinationMarker.run(.repeatForever(.sequence([
            .scale(to: 0.7, duration: 0.35),
            .scale(to: 1.0, duration: 0.35),
        ])))
        world.addChild(destinationMarker)
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        let delta = min(1.0 / 20, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime

        // 斜めには歩かない。縦横どちらか強いほうだけを使う
        var input = moveInput
        if abs(input.dx) >= abs(input.dy) {
            input.dy = 0
        } else {
            input.dx = 0
        }
        let length = hypot(input.dx, input.dy)
        if length > 1 {
            input = CGVector(dx: input.dx / length, dy: input.dy / length)
        }
        var velocity = CGVector.zero
        if length > 0.15 {
            // キーボードで動かしたらタップでの移動はやめる
            if !path.isEmpty || touchPoint != nil { stopWalking() }
            velocity = CGVector(dx: input.dx * Self.walkSpeed, dy: input.dy * Self.walkSpeed)
        } else {
            // 指を置いたまま画面が動いたときも、指の下の場所を目指す
            updateDestinationFromTouch()
            velocity = pathVelocity(delta: delta)
        }
        player.physicsBody?.velocity = velocity

        let isMoving = hypot(velocity.dx, velocity.dy) > 1
        if isMoving {
            if abs(velocity.dx) > abs(velocity.dy) {
                facing = .side
                player.xScale = velocity.dx < 0 ? -1 : 1
            } else {
                facing = velocity.dy > 0 ? .up : .down
                player.xScale = 1
            }
            // 速く歩くときは足の動きも速くする
            let speed = hypot(velocity.dx, velocity.dy)
            walkTime += delta * min(3, max(1, speed / Self.walkSpeed))
        } else {
            walkTime = 0
            if let focusTarget {
                face(toward: focusTarget)
            }
        }
        updatePlayerTexture(isMoving: isMoving)
    }

    /// 止まっているときに、指定した地点のほうを向く
    private func face(toward target: CGPoint) {
        let dx = target.x - player.position.x
        let dy = target.y - player.position.y
        guard hypot(dx, dy) > 2 else { return }
        if abs(dx) > abs(dy) {
            facing = .side
            player.xScale = dx < 0 ? -1 : 1
        } else {
            facing = dy > 0 ? .up : .down
            player.xScale = 1
        }
    }

    override func didSimulatePhysics() {
        player.zPosition = Self.depth(forBaseY: player.position.y)
        updateFollowers()
        updateCamera()
        updateFocus()
    }

    // MARK: - Party

    /// ついて歩く仲間を決める。はじめはプレイヤーと同じ場所に重ねておき、歩き出すと列になる
    func setFollowers(_ nodes: [SKNode]) {
        followers = nodes
        resetTrail()
    }

    /// プレイヤーと仲間を指定のマスへ移す（場面の切り替えや、時間の巻き戻し）
    func placePlayer(column: CGFloat, row: CGFloat) {
        stopWalking()
        player.position = point(column: column, row: row)
        player.zPosition = Self.depth(forBaseY: player.position.y)
        resetTrail()
        updateCamera()
    }

    /// プレイヤーに演出の動きをさせて、終わるまで待つ（踊る、跳ねるなど）
    func runOnPlayer(_ action: SKAction) async {
        await run(action, on: player)
    }

    /// 仲間が動くたびに呼ばれる。サブクラスで向きや歩くコマを変える（止まっているときは delta が 0）
    func followerDidMove(_ follower: SKNode, by delta: CGVector) {}

    private func resetTrail() {
        trail = [player.position]
        for follower in followers {
            follower.position = player.position
            follower.zPosition = Self.depth(forBaseY: player.position.y) + 0.1
        }
    }

    private func updateFollowers() {
        guard !followers.isEmpty else { return }
        let position = player.position
        if let latest = trail.first {
            if hypot(position.x - latest.x, position.y - latest.y) >= 1 {
                trail.insert(position, at: 0)
            }
        } else {
            trail = [position]
        }
        for (index, follower) in followers.enumerated() {
            let target = pointOnTrail(atDistance: Self.followerSpacing * CGFloat(index + 1))
            let delta = CGVector(dx: target.x - follower.position.x, dy: target.y - follower.position.y)
            follower.position = target
            // 前の人より少し奥に描く（同じ高さで重なったときにプレイヤーが手前に来るように）
            follower.zPosition = Self.depth(forBaseY: target.y) - 0.1 * CGFloat(index + 1)
            followerDidMove(follower, by: delta)
        }
        trimTrail(keeping: Self.followerSpacing * CGFloat(followers.count + 1))
    }

    /// 通った道を新しいほうから distance だけさかのぼった地点
    private func pointOnTrail(atDistance distance: CGFloat) -> CGPoint {
        var remaining = distance
        for index in 0..<(trail.count - 1) {
            let from = trail[index], to = trail[index + 1]
            let length = hypot(to.x - from.x, to.y - from.y)
            if length >= remaining, length > 0 {
                let t = remaining / length
                return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
            }
            remaining -= length
        }
        return trail.last ?? player.position
    }

    private func trimTrail(keeping distance: CGFloat) {
        var total: CGFloat = 0
        for index in 0..<(trail.count - 1) {
            total += hypot(trail[index + 1].x - trail[index].x, trail[index + 1].y - trail[index].y)
            if total > distance {
                trail.removeSubrange((index + 2)...)
                return
            }
        }
    }

    // MARK: - Tap-to-walk

    /// タップでの移動をやめてその場に止まる
    func stopWalking() {
        touchPoint = nil
        path = []
        destinationCell = nil
        destinationMarker.isHidden = true
        player.physicsBody?.velocity = .zero
    }

    private func updateDestinationFromTouch() {
        guard let touchPoint, view != nil else { return }
        walk(to: convertPoint(fromView: touchPoint))
    }

    /// 目的地（シーン座標）までの経路を探して歩き始める
    private func walk(to target: CGPoint) {
        let mapSize = CGSize(width: CGFloat(columns) * Self.tile, height: CGFloat(rows) * Self.tile)
        let target = CGPoint(x: min(max(target.x, 0), mapSize.width - 1), y: min(max(target.y, 0), mapSize.height - 1))

        // 家具などの上をタップしたときは、それを調べられる場所へ向かう。それ以外は一番近い立てる場所へ
        var goalPoint = target
        if !canStand(at: target), let zone = zones.first(where: { $0.rect.union(CGRect(origin: $0.anchor, size: .zero)).contains(target) }) {
            goalPoint = CGPoint(x: zone.rect.midX, y: zone.rect.midY)
        }
        guard let goal = nearestWalkableCell(to: cell(containing: goalPoint)) else { return }
        guard goal != destinationCell else { return }
        destinationCell = goal

        let start = player.position
        guard let startCell = nearestWalkableCell(to: cell(containing: start)),
              let cells = findPath(from: startCell, to: goal) else { return }
        let end = center(of: goal)

        // 縦横にだけ歩くよう、曲がり角の地点だけを残す
        var waypoints: [CGPoint] = []
        // 格子の中心からずれているときは、まず横、次に縦にずれを直してから歩き出す
        let first = center(of: startCell)
        if start.x != first.x && start.y != first.y {
            waypoints.append(CGPoint(x: first.x, y: start.y))
        }
        waypoints.append(first)
        for index in cells.indices.dropFirst().dropLast() {
            let previous = cells[index - 1], current = cells[index], next = cells[index + 1]
            let isStraight = (previous.x == current.x && current.x == next.x) || (previous.y == current.y && current.y == next.y)
            if !isStraight {
                waypoints.append(center(of: current))
            }
        }
        if cells.count > 1 {
            waypoints.append(end)
        }
        path = waypoints
        pathSpeed = Self.tapWalkSpeed
        stuckTime = 0
        destinationMarker.position = end
        destinationMarker.isHidden = false
    }

    /// 経路の次の地点へ向かう速度。着いたら次の地点へ進み、最後まで着いたら止まる
    private func pathVelocity(delta: TimeInterval) -> CGVector {
        let position = player.position
        while let next = path.first, hypot(next.x - position.x, next.y - position.y) < 1 {
            path.removeFirst()
        }
        guard let next = path.first else {
            destinationMarker.isHidden = true
            return .zero
        }
        // 壁などに引っかかって進めないときは諦める
        if let body = player.physicsBody, hypot(body.velocity.dx, body.velocity.dy) < Self.walkSpeed * 0.2, delta > 0 {
            stuckTime += delta
        } else {
            stuckTime = 0
        }
        if stuckTime > 0.4 && touchPoint == nil {
            stopWalking()
            return .zero
        }
        let dx = next.x - position.x
        let dy = next.y - position.y
        let distance = hypot(dx, dy)
        // 目的地を通り過ぎないよう、最後の1フレームは速さを落とす
        let speed = min(pathSpeed, distance / max(delta, 1.0 / 60))
        return CGVector(dx: dx / distance * speed, dy: dy / distance * speed)
    }

    /// 足元の当たり判定（少し余裕をもたせる）が障害物に重ならないか
    private func canStand(at feet: CGPoint) -> Bool {
        let rect = CGRect(x: feet.x - 5.5, y: feet.y - 0.5, width: 11, height: 7)
        return !obstacles.values.contains { $0.rect.intersects(rect) }
    }

    private var gridSize: (columns: Int, rows: Int) {
        (Int(CGFloat(columns) * Self.tile / Self.navCell), Int(CGFloat(rows) * Self.tile / Self.navCell))
    }

    private func cell(containing point: CGPoint) -> GridCell {
        let size = gridSize
        return GridCell(
            x: min(max(Int((point.x / Self.navCell).rounded(.down)), 0), size.columns - 1),
            y: min(max(Int((point.y / Self.navCell).rounded(.down)), 0), size.rows - 1)
        )
    }

    private func center(of cell: GridCell) -> CGPoint {
        CGPoint(x: (CGFloat(cell.x) + 0.5) * Self.navCell, y: (CGFloat(cell.y) + 0.5) * Self.navCell)
    }

    private func isWalkable(_ cell: GridCell) -> Bool {
        let size = gridSize
        guard (0..<size.columns).contains(cell.x), (0..<size.rows).contains(cell.y) else { return false }
        if walkableGrid == nil {
            var grid = [Bool](repeating: false, count: size.columns * size.rows)
            for y in 0..<size.rows {
                for x in 0..<size.columns {
                    grid[y * size.columns + x] = canStand(at: center(of: GridCell(x: x, y: y)))
                }
            }
            walkableGrid = grid
        }
        return walkableGrid![cell.y * size.columns + cell.x]
    }

    /// 立てる格子のうち一番近いもの
    private func nearestWalkableCell(to cell: GridCell) -> GridCell? {
        if isWalkable(cell) { return cell }
        let size = gridSize
        var visited: Set<GridCell> = [cell]
        var queue = [cell]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let next = GridCell(x: current.x + dx, y: current.y + dy)
                guard (0..<size.columns).contains(next.x), (0..<size.rows).contains(next.y), visited.insert(next).inserted else { continue }
                if isWalkable(next) { return next }
                queue.append(next)
            }
        }
        return nil
    }

    /// A* で格子上の経路を探す。縦横にだけ進み、なるべく曲がる回数が少ない経路を選ぶ
    private func findPath(from start: GridCell, to goal: GridCell) -> [GridCell]? {
        if start == goal { return [start] }
        let size = gridSize
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        /// 曲がるときに上乗せする手間（格子何マス分か）。大きいほど曲がり角の少ない経路になる
        let turnCost = 3.0
        // 状態は「どの格子に・どの向きで入ったか」
        func state(_ cell: GridCell, _ direction: Int) -> Int { (cell.y * size.columns + cell.x) * 4 + direction }
        func heuristic(_ cell: GridCell) -> Double {
            Double(abs(cell.x - goal.x) + abs(cell.y - goal.y))
        }

        var cost = [Double](repeating: .infinity, count: size.columns * size.rows * 4)
        var cameFrom = [Int](repeating: -1, count: size.columns * size.rows * 4)
        var open = MinHeap()
        // 出発時はどの向きにも曲がらずに出られる
        for direction in directions.indices {
            cost[state(start, direction)] = 0
            open.push(state: state(start, direction), priority: heuristic(start))
        }

        while let (currentState, priority) = open.pop() {
            let cellIndex = currentState / 4
            let direction = currentState % 4
            let current = GridCell(x: cellIndex % size.columns, y: cellIndex / size.columns)
            let currentCost = cost[currentState]
            if priority > currentCost + heuristic(current) + 0.0001 { continue }
            if current == goal {
                var cells: [GridCell] = []
                var at = currentState
                while true {
                    cells.append(GridCell(x: (at / 4) % size.columns, y: (at / 4) / size.columns))
                    guard cameFrom[at] >= 0 else { break }
                    at = cameFrom[at]
                }
                return Array(cells.reversed())
            }
            for (nextDirection, (dx, dy)) in directions.enumerated() {
                let next = GridCell(x: current.x + dx, y: current.y + dy)
                guard isWalkable(next) else { continue }
                let newCost = currentCost + 1 + (nextDirection == direction ? 0 : turnCost)
                let nextState = state(next, nextDirection)
                if newCost < cost[nextState] {
                    cost[nextState] = newCost
                    cameFrom[nextState] = currentState
                    open.push(state: nextState, priority: newCost + heuristic(next))
                }
            }
        }
        return nil
    }

    /// A* 用の最小ヒープ
    private struct MinHeap {
        private var items: [(state: Int, priority: Double)] = []

        mutating func push(state: Int, priority: Double) {
            items.append((state, priority))
            var child = items.count - 1
            while child > 0 {
                let parent = (child - 1) / 2
                guard items[child].priority < items[parent].priority else { break }
                items.swapAt(child, parent)
                child = parent
            }
        }

        mutating func pop() -> (Int, Double)? {
            guard !items.isEmpty else { return nil }
            items.swapAt(0, items.count - 1)
            let top = items.removeLast()
            var parent = 0
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var smallest = parent
                if left < items.count && items[left].priority < items[smallest].priority { smallest = left }
                if right < items.count && items[right].priority < items[smallest].priority { smallest = right }
                guard smallest != parent else { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
            return (top.state, top.priority)
        }
    }

    private func updatePlayerTexture(isMoving: Bool) {
        let frame: String
        if isMoving {
            let frames = ["step1", "stand", "step2", "stand"]
            frame = frames[Int(walkTime / 0.13) % frames.count]
        } else {
            frame = "stand"
        }
        let name = "\(playerSpritePrefix)_\(facing.rawValue)_\(frame)"
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

        func clamp(_ value: CGFloat, visible: CGFloat, map: CGFloat, lowerInset: CGFloat = 0) -> CGFloat {
            guard visible < map else { return map / 2 }
            return min(max(value, visible / 2 - lowerInset), map - visible / 2)
        }
        let target = CGPoint(x: player.position.x, y: player.position.y + 8)
        // 画面の1ドットに揃えてにじみを防ぐ
        let x = (clamp(target.x, visible: visible.width, map: mapSize.width) / scale).rounded() * scale
        let y = (clamp(target.y, visible: visible.height, map: mapSize.height, lowerInset: bottomInset * scale) / scale).rounded() * scale
        playerCamera.position = CGPoint(x: x, y: y)
    }

    private func updateFocus() {
        for index in zones.indices where zones[index].follow != nil {
            zones[index].track()
        }
        let feet = player.position
        let available = zones.filter { isAvailable?($0.interactable) ?? true }
        // 決められた範囲に入っていればそれを、なければ（入るだけで進むもの以外は）まわりに立っている相手のうち近いものを選ぶ
        let zone = available.first { $0.rect.contains(feet) }
            ?? available
            .filter { !$0.interactable.triggersOnEnter && $0.aroundTarget.contains(feet) }
            .min { hypot($0.target.x - feet.x, $0.target.y - feet.y) < hypot($1.target.x - feet.x, $1.target.y - feet.y) }
        if let zone {
            bubble.isHidden = false
            let textureName = isStoryTarget?(zone.interactable) == true ? "bubble_story" : "bubble"
            if textureName != bubbleTextureName {
                bubbleTextureName = textureName
                bubble.texture = Self.texture(textureName)
            }
            // 吹き出しはその場で上下に 2 ドット揺れるので、それより大きくずれたときだけ置き直す（動く範囲用）
            if bubble.position.x != zone.anchor.x || abs(bubble.position.y - zone.anchor.y) > 2.5 {
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
        if let zone, !zone.interactable.triggersOnEnter {
            focusTarget = zone.target
        } else {
            focusTarget = nil
        }
        let newFocus = zone?.interactable
        if newFocus != focus {
            focus = newFocus
            onFocusChange?(newFocus)
        }
    }
}
