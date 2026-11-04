import SpriteKit

/// 『銀河鉄道の夜』の本の中で調べられるもの
enum GingaInteractable: WalkInteractable, Hashable {
    /// 空いている座席（手紙を置いたり拾ったりする）
    case seat(Int)
    /// 車両の間の扉（0: 一両目の前、1: 二両目の前、2: 三両目の前＝停車場へ）
    case door(Int)
    /// 扉を抜けた先。手紙を置き忘れていたら引き返す
    case doorway(Int)
    case giovanni
    case campanella
    case conductor
    case birdCatcher
    case lighthouseKeeper
    /// 終点の停車場にいる作者の幽霊
    case author

    var prompt: String {
        switch self {
        case .seat: "座席 ── ビロード張りの、空いている席なのだ"
        case .door(2): "扉 ── この向こうが、終点の停車場なのだ"
        case .door: "扉 ── つぎの車両への扉なのだ"
        case .doorway: "扉の向こう"
        case .giovanni: "ジョバンニ ── 窓の外をじっと見ているのだ"
        case .campanella: "カムパネルラ ── 少し青ざめた顔をしているのだ"
        case .conductor: "車掌 ── 赤い帽子の、背の高い人なのだ"
        case .birdCatcher: "鳥捕り ── 大きな包みをかかえているのだ"
        case .lighthouseKeeper: "燈台看守 ── 大きな苹果を両手でかかえているのだ"
        case .author: "作者 ── 帽子をかぶった、静かな人なのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .seat: "しらべる"
        case .door: "あける"
        default: "はなす"
        }
    }

    var triggersOnEnter: Bool {
        if case .doorway = self { return true }
        return false
    }
}

/// 『銀河鉄道の夜』の本の中。銀河鉄道の三両の客車と、終点の停車場。
/// ずんだもんはサチの手紙を両手でかかえて運ぶ。かかえている間は扉を開けたり物を受け取ったりできない
final class GingaScene: WalkScene<GingaInteractable> {
    /// 手紙を置いている座席（nil ならかかえている）
    private(set) var letterSeat: Int?
    var isCarryingLetter: Bool { letterSeat == nil }
    /// 手紙を置いている車両（0〜2。かかえていれば nil）
    var letterCar: Int? { letterSeat.map { $0 / 2 } }

    private let flags: Set<StoryFlag>
    private let sachi = SKSpriteNode()
    private let author = SKSpriteNode()
    private let letter = SKSpriteNode(texture: GingaScene.texture("ginga_letter_small"))
    private var doorNodes: [SKSpriteNode] = []
    private var doorObstacles: [Int] = []
    private(set) var openedDoors: Set<Int> = []
    private var passengerNodes: [GingaInteractable: SKSpriteNode] = [:]

    /// 扉の行（下の車両から順に）
    private static let doorRows: [CGFloat] = [30, 19, 8]
    /// 空いている座席（列・行）。左の座席は 1、右の座席は 7 から2マス
    private static let seatSpots: [(column: CGFloat, row: CGFloat)] = [
        (1, 38), (7, 35),  // 一両目
        (1, 24), (1, 27),  // 二両目
        (7, 13), (1, 16),  // 三両目
    ]

    init(flags: Set<StoryFlag>) {
        self.flags = flags
        // 鳥捕りは、お菓子をくれたあと、いつのまにかいなくなっている
        // 途中から入り直したときは、進んだ車両から
        let start: (column: CGFloat, row: CGFloat) = if flags.contains(.chapter3CandyEaten) {
            (4.5, 17.4)
        } else if flags.contains(.chapter3TicketShown) {
            (4.5, 28.4)
        } else {
            (4.5, 39.2)
        }
        super.init(columns: 10, rows: 42, playerStart: start)
        backgroundColor = SKColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1)
    }

    override func buildMap() {
        buildPlatform()
        for car in 0..<3 {
            buildCar(top: Self.doorRows[2 - car] + 1)
        }
        buildDoors()
        buildPassengers()
        buildParty()
    }

    // MARK: - Map

    private func buildPlatform() {
        for row in 0..<8 {
            for column in 0..<columns {
                if row < 3 || column == 0 || column == columns - 1 {
                    place("ginga_space_\((row * 3 + column) % 3)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
                } else {
                    place("ginga_platform", column: CGFloat(column), row: CGFloat(row), z: -10_000)
                }
            }
        }
        for row in 3..<8 {
            place("ginga_susuki", column: 0, row: CGFloat(row), z: -9_000)
            place("ginga_susuki", column: CGFloat(columns - 1), row: CGFloat(row), z: -9_000)
        }
        place("ginga_sign", column: 1.2, row: 2.6)
        place("ginga_bench", column: 6.6, row: 3.2)
        let lamp = place("lamp_0", column: 3.6, row: 2.2)
        lamp.run(.repeatForever(.animate(with: [Self.texture("lamp_0"), Self.texture("lamp_1")], timePerFrame: 0.3)))
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 3.3)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 6.6, row: 3.6, width: 2, height: 0.5)
    }

    /// 1両分の客車（top の行から10行）
    private func buildCar(top: CGFloat) {
        let windowFrames = (l: [Self.texture("ginga_window_l_0"), Self.texture("ginga_window_l_1")],
                            r: [Self.texture("ginga_window_r_0"), Self.texture("ginga_window_r_1")])
        for offset in 0..<10 {
            let row = top + CGFloat(offset)
            for column in 1..<(columns - 1) {
                place((4...5).contains(column) ? "ginga_carpet" : "ginga_floor", column: CGFloat(column), row: row, z: -10_000)
            }
            let isWindow = offset % 3 == 1
            let left = place(isWindow ? "ginga_window_l_0" : "ginga_wall", column: 0, row: row, z: -9_000)
            let right = place(isWindow ? "ginga_window_r_0" : "ginga_wall", column: CGFloat(columns - 1), row: row, z: -9_000)
            if isWindow {
                left.run(.repeatForever(.animate(with: windowFrames.l, timePerFrame: 0.5)))
                right.run(.repeatForever(.animate(with: windowFrames.r, timePerFrame: 0.5)))
            }
        }
        // 座席（左右に3つずつ）
        for offset: CGFloat in [1, 4, 7] {
            for column: CGFloat in [1, 7] {
                place("ginga_seat", column: column, row: top + offset)
                addObstacle(column: column, row: top + offset + 0.2, width: 2, height: 0.8)
            }
        }
        if top + 10 >= CGFloat(rows) {
            addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
        }
    }

    private func buildDoors() {
        let opened = [flags.contains(.chapter3TicketShown), flags.contains(.chapter3CandyEaten), false]
        for (index, row) in Self.doorRows.enumerated() {
            for column in 0..<columns where !(4...5).contains(column) {
                place("ginga_wall", column: CGFloat(column), row: row, z: -9_000)
            }
            addObstacle(column: 0, row: row, width: 4, height: 1)
            addObstacle(column: 6, row: row, width: 4, height: 1)
            let door = place(opened[index] ? "ginga_door_open" : "ginga_door_closed", column: 4, row: row, z: -9_000)
            doorNodes.append(door)
            let obstacle = addObstacle(column: 4, row: row, width: 2, height: 1)
            doorObstacles.append(obstacle)
            if opened[index] {
                removeObstacle(obstacle)
                openedDoors.insert(index)
            }
            // 扉を抜けた先で、手紙を忘れていないか確かめる
            addZone(column: 3.5, row: row - 1.4, width: 3, height: 1.2, interactable: .doorway(index), anchor: (5, row - 1.6))
            addZone(column: 3.5, row: row + 1, width: 3, height: 1.3, interactable: .door(index), anchor: (5, row - 0.2))
        }
        for (index, spot) in Self.seatSpots.enumerated() {
            let column = spot.column == 1 ? 3.0 : 5.8
            addZone(column: column, row: spot.row - 0.1, width: 1.2, height: 1.4, interactable: .seat(index), anchor: (spot.column + 1, spot.row - 0.4))
        }
    }

    private func buildPassengers() {
        // 一両目: ジョバンニとカムパネルラ、車掌
        addPassenger("giovanni", seat: (1, 32), interactable: .giovanni)
        addPassenger("campanella", seat: (7, 32), interactable: .campanella)
        addStanding("conductor", at: (6.4, 37.8), zone: (5.5, 38.0, 2, 1.3), interactable: .conductor)
        // 二両目: 鳥捕り
        if !flags.contains(.chapter3CandyEaten) {
            addPassenger("birdcatcher", seat: (7, 21), interactable: .birdCatcher)
        }
        // 三両目: 燈台看守
        addPassenger("keeper", seat: (1, 10), interactable: .lighthouseKeeper)

        // 終点の停車場: 作者の幽霊
        let frames = [Self.texture("author_0"), Self.texture("author_1")]
        author.texture = frames[0]
        author.size = CGSize(width: 16, height: 16)
        author.anchorPoint = CGPoint(x: 0.5, y: 0)
        author.position = point(column: 5, row: 4.8)
        author.zPosition = Self.depth(forBaseY: author.position.y)
        author.alpha = 0.85
        author.run(.repeatForever(.animate(with: frames, timePerFrame: 0.5)))
        author.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1.5, duration: 0.9), .moveBy(x: 0, y: -1.5, duration: 0.9)])), withKey: "float")
        addToWorld(author)
        addZone(column: 4, row: 5.0, width: 2, height: 1.3, interactable: .author, anchor: (5, 3.6))
    }

    /// 座席に座っている乗客
    private func addPassenger(_ name: String, seat: (column: CGFloat, row: CGFloat), interactable: GingaInteractable) {
        let node = SKSpriteNode(texture: Self.texture(name))
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = point(column: seat.column + 1, row: seat.row + 0.75)
        node.zPosition = Self.depth(forBaseY: node.position.y) + 1
        addToWorld(node)
        passengerNodes[interactable] = node
        let zoneColumn = seat.column == 1 ? 3.0 : 5.8
        addZone(column: zoneColumn, row: seat.row - 0.1, width: 1.2, height: 1.4, interactable: interactable, anchor: (seat.column + 1, seat.row - 0.6))
    }

    private func addStanding(_ name: String, at spot: (column: CGFloat, row: CGFloat), zone: (column: CGFloat, row: CGFloat, width: CGFloat, height: CGFloat), interactable: GingaInteractable) {
        let node = SKSpriteNode(texture: Self.texture(name))
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = point(column: spot.column, row: spot.row)
        node.zPosition = Self.depth(forBaseY: node.position.y)
        addToWorld(node)
        addObstacle(column: spot.column - 0.3, row: spot.row - 0.3, width: 0.6, height: 0.3)
        addZone(column: zone.column, row: zone.row, width: zone.width, height: zone.height, interactable: interactable, anchor: (spot.column, spot.row - 1.3))
    }

    private func buildParty() {
        let frames = [Self.texture("sachi_normal_0"), Self.texture("sachi_normal_1")]
        sachi.texture = frames[0]
        sachi.size = CGSize(width: 16, height: 16)
        sachi.anchorPoint = CGPoint(x: 0.5, y: 0)
        sachi.alpha = 0.8
        sachi.run(.repeatForever(.animate(with: frames, timePerFrame: 0.45)))
        addToWorld(sachi)
        setFollowers([sachi])

        // 両手でかかえた手紙（ずんだもんの胸の前）
        letter.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        letter.position = CGPoint(x: 0, y: 6)
        letter.zPosition = 1
        attachToPlayer(letter)
    }

    // MARK: - 手紙

    /// 座席に手紙を置く
    func putLetter(on seat: Int) {
        letterSeat = seat
        let spot = Self.seatSpots[seat]
        letter.removeFromParent()
        letter.position = point(column: spot.column + 1, row: spot.row + 0.45)
        letter.zPosition = Self.depth(forBaseY: letter.position.y - 8) + 2
        addToWorld(letter)
    }

    /// 座席から手紙を拾って、またかかえる
    func pickUpLetter() {
        letterSeat = nil
        letter.position = CGPoint(x: 0, y: 6)
        letter.zPosition = 1
        attachToPlayer(letter)
    }

    /// 扉を開ける
    func openDoor(_ index: Int) {
        guard !openedDoors.contains(index) else { return }
        openedDoors.insert(index)
        doorNodes[index].texture = Self.texture("ginga_door_open")
        removeObstacle(doorObstacles[index])
    }

    /// 扉の手前に戻す（手紙を置き忘れたとき）
    func stepBack(from door: Int) {
        placePlayer(column: 4.5, row: Self.doorRows[door] + 1.8)
    }

    /// 乗客がふっといなくなる（鳥捕りのように）
    func vanish(_ interactable: GingaInteractable) async {
        removeZones { $0 == interactable }
        guard let node = passengerNodes[interactable] else { return }
        await run(.fadeOut(withDuration: 0.8), on: node)
        node.removeFromParent()
    }

    // MARK: - 終点

    /// 手紙が届いて、作者とサチが光に包まれる
    func glowAuthorAndSachi() async {
        letter.removeFromParent()
        sachi.texture = Self.texture("sachi_happy_0")
        sachi.removeAllActions()
        sachi.run(.repeatForever(.animate(with: [Self.texture("sachi_happy_0"), Self.texture("sachi_happy_1")], timePerFrame: 0.45)), withKey: "frames")
        for node in [author, sachi] {
            let halo = SKSpriteNode(texture: Self.texture("glow_ghost"))
            halo.blendMode = .add
            halo.position = CGPoint(x: 0, y: 8)
            halo.zPosition = 1
            halo.alpha = 0
            halo.setScale(1.6)
            node.addChild(halo)
            halo.run(.fadeAlpha(to: 0.9, duration: 1.2), withKey: "glow")
        }
        await run(.wait(forDuration: 1.4), on: author)
    }

    /// 作者が星空へ帰っていく
    func authorFadesAway() async {
        author.removeAction(forKey: "float")
        await run(.group([.moveBy(x: 0, y: 24, duration: 2.0), .fadeOut(withDuration: 2.0)]), on: author)
        removeZones { $0 == .author }
    }
}
