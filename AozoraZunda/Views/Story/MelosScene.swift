import Observation
import SpriteKit

/// 『走れメロス』の本の中で調べられるもの
enum MelosInteractable: WalkInteractable {
    /// 濁流の手前。入るとイベント
    case river
    /// 峠で山賊が待ち伏せている場所
    case bandits
    /// メロスが力尽きて倒れる場所
    case collapse
    /// 道ばたの岩（index 0 が清水の湧く岩）
    case rock(Int)
    /// 倒れているメロス
    case melosLying
    /// フィロストラトスが追いかけてくる場所
    case philostratus
    /// シラクスの城門。入ると結末へ
    case gate

    static let springRock = 0

    var prompt: String {
        switch self {
        case .river: "濁流 ── 橋が流されているのだ"
        case .bandits: "峠道 ── あやしい気配がするのだ"
        case .collapse: "道 ── 日ざしが照りつけているのだ"
        case .rock(Self.springRock): "岩 ── 細い裂け目があるのだ"
        case .rock: "岩 ── ごつごつした岩なのだ"
        case .melosLying: "メロス ── 草原に倒れているのだ"
        case .philostratus: "道 ── 誰かが追いかけてくるのだ"
        case .gate: "シラクスの城門"
        }
    }

    var actionTitle: String {
        switch self {
        case .melosLying: "はなす"
        default: "しらべる"
        }
    }

    var triggersOnEnter: Bool {
        switch self {
        case .river, .bandits, .collapse, .philostratus, .gate: true
        case .rock, .melosLying: false
        }
    }
}

/// 日没までの残り時間。画面上の太陽のメーターがこれを見る
@Observable
final class SunsetClock {
    static let total: TimeInterval = 150
    /// 残り秒数（1秒ごとに更新する）
    fileprivate(set) var remainingSeconds = Int(total)
    /// メロスが倒れて、泉を探している最中か
    fileprivate(set) var isMelosDown = false

    var fraction: Double { Double(remainingSeconds) / Self.total }
}

/// 『走れメロス』の本の中。村はずれから濁流・峠・泉をこえてシラクスの刑場へ走る。
/// メロスとタクがうしろをついてきて、日没までのカウントが進む
final class MelosScene: WalkScene<MelosInteractable> {
    /// 本の中の途中から再開・巻き戻しする場所
    enum Checkpoint {
        case start, riverCrossed, banditsPassed, revived, philostratusPassed

        var position: (column: CGFloat, row: CGFloat) {
            switch self {
            case .start: (7, 51)
            case .riverCrossed: (7, 40.6)
            case .banditsPassed: (7, 33.5)
            case .revived: (8, 25)
            case .philostratusPassed: (7, 16)
            }
        }
    }

    let clock = SunsetClock()
    /// 時間切れになったとき
    var onTimeUp: (() -> Void)?
    /// false の間は時間を止める（会話中など）
    var isClockRunning = false

    private(set) var checkpoint: Checkpoint
    private var remaining = SunsetClock.total
    private var checkpointRemaining = SunsetClock.total
    private var hasTimedOut = false
    private var lastTime: TimeInterval?

    private let melos = SKSpriteNode()
    private let taku = SKSpriteNode()
    private let selinuntius = SKSpriteNode()
    private var cross: SKSpriteNode?
    private var springRockNode: SKSpriteNode?
    private var bandits: [SKSpriteNode] = []
    private let sunset = SKSpriteNode(color: .white, size: CGSize(width: 4_000, height: 4_000))
    private var melosFacing = "up"

    private static let rockSpots: [(column: CGFloat, row: CGFloat)] = [
        (10.4, 26.6), (2, 24), (3.5, 28.4), (1.5, 31), (10.5, 22.6), (9.8, 30.6),
    ]

    init(flags: Set<StoryFlag>) {
        if flags.contains(.chapter1PhilostratusPassed) {
            checkpoint = .philostratusPassed
        } else if flags.contains(.chapter1MelosRevived) {
            checkpoint = .revived
        } else if flags.contains(.chapter1BanditsPassed) {
            checkpoint = .banditsPassed
        } else if flags.contains(.chapter1RiverCrossed) {
            checkpoint = .riverCrossed
        } else {
            checkpoint = .start
        }
        self.flags = flags
        super.init(columns: 14, rows: 56, playerStart: checkpoint.position)
        backgroundColor = SKColor(red: 0.20, green: 0.32, blue: 0.18, alpha: 1)
        // 途中から入り直したときは、進んだぶん日が傾いている
        remaining = [Checkpoint.start: 150, .riverCrossed: 120, .banditsPassed: 100, .revived: 80, .philostratusPassed: 55][checkpoint] ?? 150
        checkpointRemaining = remaining
        clock.remainingSeconds = Int(remaining.rounded(.up))
    }

    private let flags: Set<StoryFlag>

    override func buildMap() {
        buildGround()
        buildRiverAndPass()
        buildField()
        buildCity()
        buildParty()
        sunset.blendMode = .multiply
        sunset.zPosition = 9_000
        addToCamera(sunset)
        updateSunsetColor()
    }

    // MARK: - Map

    private func buildGround() {
        for row in 0..<rows {
            for column in 0..<columns {
                let variant = (row * 7 + column * 5) % 3
                if row <= 11 {
                    place("melos_stone_\((row + column) % 2)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
                } else {
                    place("melos_grass_\(variant)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
                }
            }
        }
        // 道（峠のところは少し曲がる）
        for row in 12..<rows {
            let offset: Int = switch row {
            case 33...36: -1
            case 37...40: 1
            default: 0
            }
            for column in [6 + offset, 7 + offset] {
                place("melos_road_\((row + column) % 2)", column: CGFloat(column), row: CGFloat(row), z: -9_900)
            }
        }
        // 野の花
        for (column, row) in [(3, 50), (10, 48), (2, 46), (11, 53), (4, 20), (10, 15), (3, 14), (11, 19), (9, 26), (4, 26)] {
            place("melos_flowers", column: CGFloat(column), row: CGFloat(row), z: -9_800)
        }
        // 左右の並木
        for row in stride(from: 12, to: rows - 1, by: 3) where !(32...41).contains(row) {
            for column in [-0.4, 12.4] {
                place("melos_tree", column: column, row: CGFloat(row))
            }
        }
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
    }

    private func buildRiverAndPass() {
        // 濁流（橋は流されている）
        let frames = (0..<3).map { Self.texture("melos_river_\($0)") }
        for row in 42...44 {
            for column in 0..<columns {
                let water = place("melos_river_\((row + column) % 3)", column: CGFloat(column), row: CGFloat(row), z: -9_700)
                water.run(.repeatForever(.animate(with: frames, timePerFrame: 0.14)))
            }
        }
        addObstacle(column: 0, row: 42, width: CGFloat(columns), height: 3)
        if checkpoint == .start {
            addZone(column: 1, row: 45, width: 12, height: 1.2, interactable: .river, anchor: (7, 44.2))
        }

        // 峠の岩壁（真ん中の峠道だけ通れる）
        for row in 32...41 {
            for column in 0..<columns where !(4...9).contains(column) {
                place("melos_cliff", column: CGFloat(column), row: CGFloat(row), z: -9_600)
            }
        }
        addObstacle(column: 0, row: 32, width: 4, height: 10)
        addObstacle(column: 10, row: 32, width: 4, height: 10)

        // 山賊（はじめは隠れている）
        for (index, column) in [5.5, 7.0, 8.5].enumerated() {
            let bandit = SKSpriteNode(texture: Self.texture("bandit"))
            bandit.anchorPoint = CGPoint(x: 0.5, y: 0)
            bandit.position = point(column: column, row: 34.6 - CGFloat(index % 2) * 0.4)
            bandit.zPosition = Self.depth(forBaseY: bandit.position.y)
            bandit.alpha = 0
            addToWorld(bandit)
            bandits.append(bandit)
        }
        if !flags.contains(.chapter1BanditsPassed) {
            addZone(column: 4, row: 36, width: 6, height: 1.4, interactable: .bandits, anchor: (7, 34.6))
        }
    }

    private func buildField() {
        for (index, spot) in Self.rockSpots.enumerated() {
            let rock = place(index == MelosInteractable.springRock ? "melos_rock_cracked" : "melos_rock", column: spot.column, row: spot.row)
            if index == MelosInteractable.springRock {
                springRockNode = rock
                if flags.contains(.chapter1MelosRevived) {
                    rock.texture = Self.texture("melos_spring")
                }
            }
            addObstacle(column: spot.column + 0.1, row: spot.row + 0.4, width: 0.8, height: 0.6)
            addZone(
                column: spot.column - 0.5, row: spot.row + 1, width: 2, height: 1.2,
                interactable: .rock(index), anchor: (spot.column + 0.5, spot.row - 0.6)
            )
        }
        if !flags.contains(.chapter1MelosRevived) {
            addZone(column: 5, row: 29, width: 4, height: 1.2, interactable: .collapse, anchor: (7, 28.2))
        }
        if !flags.contains(.chapter1PhilostratusPassed) {
            addZone(column: 1, row: 18, width: 12, height: 1.2, interactable: .philostratus, anchor: (7, 17.2))
        }
    }

    private func buildCity() {
        // 城壁と城門
        for column in 0..<columns where !(6...7).contains(column) {
            place("melos_city_wall_top", column: CGFloat(column), row: 10)
            place("melos_city_wall", column: CGFloat(column), row: 11)
        }
        place("melos_gate_arch", column: 6, row: 10)
        addObstacle(column: 0, row: 10, width: 6, height: 2)
        addObstacle(column: 8, row: 10, width: 6, height: 2)
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 1)
        addZone(column: 5.5, row: 12, width: 3, height: 1.2, interactable: .gate, anchor: (7, 10.6))

        // 刑場の磔台
        let cross = place(flags.contains(.chapter1ReachedEnd) ? "melos_cross_empty" : "melos_cross_tied", column: 6, row: 2)
        self.cross = cross
        addObstacle(column: 6, row: 4.3, width: 2, height: 0.7)

        selinuntius.texture = Self.texture("selinuntius")
        selinuntius.size = CGSize(width: 16, height: 16)
        selinuntius.anchorPoint = CGPoint(x: 0.5, y: 0)
        selinuntius.isHidden = true
        addToWorld(selinuntius)
    }

    private func buildParty() {
        melos.texture = Self.texture("melos_up_stand")
        melos.size = CGSize(width: 16, height: 16)
        melos.anchorPoint = CGPoint(x: 0.5, y: 0)
        addToWorld(melos)

        let takuFrames = [Self.texture("taku_normal_0"), Self.texture("taku_normal_1")]
        taku.texture = takuFrames[0]
        taku.size = CGSize(width: 16, height: 16)
        taku.anchorPoint = CGPoint(x: 0.5, y: 0)
        taku.alpha = 0.85
        taku.run(.repeatForever(.animate(with: takuFrames, timePerFrame: 0.45)))
        addToWorld(taku)

        setFollowers([melos, taku])
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        let delta = min(1.0 / 20, currentTime - (lastTime ?? currentTime))
        lastTime = currentTime
        guard isClockRunning, !hasTimedOut else { return }
        remaining = max(0, remaining - delta)
        let seconds = Int(remaining.rounded(.up))
        if seconds != clock.remainingSeconds {
            clock.remainingSeconds = seconds
            updateSunsetColor()
        }
        if remaining <= 0 {
            hasTimedOut = true
            onTimeUp?()
        }
    }

    /// 日が傾くほど、景色を夕焼け色に染める
    private func updateSunsetColor() {
        let progress = 1 - clock.fraction
        func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        let t = CGFloat(progress)
        let color: SKColor = t < 0.6
            ? SKColor(red: 1, green: mix(1, 0.88, t / 0.6), blue: mix(1, 0.72, t / 0.6), alpha: 1)
            : SKColor(red: 1, green: mix(0.88, 0.64, (t - 0.6) / 0.4), blue: mix(0.72, 0.52, (t - 0.6) / 0.4), alpha: 1)
        sunset.color = color
    }

    override func followerDidMove(_ follower: SKNode, by delta: CGVector) {
        guard follower === melos else { return }
        let isMoving = hypot(delta.dx, delta.dy) > 0.2
        if isMoving {
            if abs(delta.dx) > abs(delta.dy) {
                melosFacing = "side"
                melos.xScale = delta.dx < 0 ? -1 : 1
            } else {
                melosFacing = delta.dy > 0 ? "up" : "down"
                melos.xScale = 1
            }
        }
        let frame = isMoving ? (Int(CACurrentMediaTime() / 0.13) % 2 == 0 ? "step1" : "step2") : "stand"
        melos.texture = Self.texture("melos_\(melosFacing)_\(frame)")
    }

    // MARK: - 時間

    /// 間違えたときなどに、日没までの時間を減らす
    func spendTime(_ seconds: TimeInterval) {
        remaining = max(1, remaining - seconds)
        clock.remainingSeconds = Int(remaining.rounded(.up))
        updateSunsetColor()
    }

    /// 場面を切り抜けたところを、巻き戻しの戻り先にする
    func setCheckpoint(_ newCheckpoint: Checkpoint) {
        checkpoint = newCheckpoint
        checkpointRemaining = remaining
    }

    /// 時間切れのあと、少し前のページから読み直す
    func rewind() {
        remaining = max(checkpointRemaining, 45)
        clock.remainingSeconds = Int(remaining.rounded(.up))
        hasTimedOut = false
        updateSunsetColor()
        let position = checkpoint.position
        placePlayer(column: position.column, row: position.row)
    }

    // MARK: - 場面の演出

    func removeTrigger(_ interactable: MelosInteractable) {
        removeZones { $0 == interactable }
    }

    /// 濁流を泳ぎ切って、向こう岸へ
    func crossRiver() {
        removeTrigger(.river)
        placePlayer(column: Checkpoint.riverCrossed.position.column, row: Checkpoint.riverCrossed.position.row)
        setCheckpoint(.riverCrossed)
    }

    func showBandits() async {
        for bandit in bandits {
            bandit.run(.fadeIn(withDuration: 0.4), withKey: "appear")
        }
        await run(.wait(forDuration: 0.5), on: melos)
    }

    /// 山賊が逃げていく
    func chaseOffBandits() async {
        removeTrigger(.bandits)
        for (index, bandit) in bandits.enumerated() {
            bandit.run(.sequence([
                .wait(forDuration: Double(index) * 0.1),
                .group([.moveBy(x: index == 1 ? 0 : (index == 0 ? -24 : 24), y: 40, duration: 0.8), .fadeOut(withDuration: 0.8)]),
            ]), withKey: "flee")
        }
        await run(.wait(forDuration: 1.0), on: melos)
        setCheckpoint(.banditsPassed)
    }

    /// メロスが力尽きて倒れる。列から外れて道ばたに横たわる
    func collapseMelos() {
        removeTrigger(.collapse)
        setFollowers([taku])
        melos.removeAllActions()
        melos.xScale = 1
        melos.texture = Self.texture("melos_collapsed")
        melos.position = point(column: 7, row: 28.2)
        melos.zPosition = Self.depth(forBaseY: melos.position.y)
        addZone(column: 6, row: 28.5, width: 2, height: 1.2, interactable: .melosLying, anchor: (7, 27.2))
        clock.isMelosDown = true
    }

    /// 岩の裂け目から清水が湧き出す
    func revealSpring() {
        springRockNode?.texture = Self.texture("melos_spring")
    }

    /// メロスが泉の水を飲んで立ち上がり、また列に加わる
    func reviveMelos() async {
        removeZones { $0 == .melosLying }
        let spring = Self.rockSpots[MelosInteractable.springRock]
        melos.texture = Self.texture("melos_side_stand")
        await run(.move(to: point(column: spring.column + 0.5, row: spring.row + 1.3), duration: 1.0), on: melos)
        await run(.wait(forDuration: 0.6), on: melos)
        melos.texture = Self.texture("melos_down_stand")
        clock.isMelosDown = false
        setFollowers([melos, taku])
        placePlayer(column: Checkpoint.revived.position.column, row: Checkpoint.revived.position.row)
        setCheckpoint(.revived)
    }

    func passPhilostratus() {
        removeTrigger(.philostratus)
        setCheckpoint(.philostratusPassed)
    }

    /// 刑場に飛び込み、磔台の前へ
    func enterExecutionGround() async {
        removeTrigger(.gate)
        isClockRunning = false
        placePlayer(column: 7, row: 8.6)
        setFollowers([taku])
        melos.position = point(column: 7, row: 7.6)
        melos.texture = Self.texture("melos_up_step1")
        await run(.move(to: point(column: 7.2, row: 5.6), duration: 0.6), on: melos)
        melos.texture = Self.texture("melos_up_stand")
    }

    /// セリヌンティウスの縄がほどかれる
    func freeSelinuntius() async {
        cross?.texture = Self.texture("melos_cross_empty")
        selinuntius.position = point(column: 6.2, row: 5.6)
        selinuntius.zPosition = Self.depth(forBaseY: selinuntius.position.y)
        selinuntius.alpha = 0
        selinuntius.isHidden = false
        await run(.fadeIn(withDuration: 0.5), on: selinuntius)
        melos.xScale = -1
        melos.texture = Self.texture("melos_side_stand")
    }

    /// 二人が抱き合う
    func embrace() async {
        await run(.group([
            .move(to: point(column: 6.6, row: 5.6), duration: 0.3),
        ]), on: selinuntius)
        await run(.sequence([.moveBy(x: 0, y: 2, duration: 0.15), .moveBy(x: 0, y: -2, duration: 0.15)]), on: melos)
    }
}
