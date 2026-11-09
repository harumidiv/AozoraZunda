import Observation
import SpriteKit

/// 山猫軒の扉の注文に応える場所
enum YamanekoStation: Int, CaseIterable {
    /// 鏡とブラシ（髪をきちんとして、はきものの泥を落とす）
    case mirror
    /// 黒い台（鉄砲と弾丸を置く）
    case stand
    /// 釘（帽子と外套と靴をとる）
    case hooks
    /// 金庫（金物類を置く）
    case safe
    /// 硝子の壺（クリームを塗る）
    case cream
    /// 小さなクリームの壺（耳にも塗る）
    case creamSmall
    /// 金ピカの香水の瓶
    case perfume
    /// 青い瀬戸の塩壺
    case salt

    /// どの扉の手前の部屋にあるか（その扉を開ける前に済ませる注文）
    var room: Int {
        switch self {
        case .mirror: 2
        case .stand, .hooks: 3
        case .safe, .cream: 4
        case .creamSmall, .perfume: 5
        case .salt: 6
        }
    }
}

/// 『注文の多い料理店』の本の中で調べられるもの
enum YamanekoInteractable: WalkInteractable, Hashable {
    /// 注文の札がかかった扉（0: 玄関の硝子戸 … 5: 金の扉、6: いちばん奥の扉）
    case door(Int)
    /// 扉を抜けた先（扉の裏側の注文を読む）
    case doorway(Int)
    case station(YamanekoStation)
    case signboard

    var prompt: String {
        switch self {
        case .door(0): "硝子の開き戸 ── 金文字で何か書いてあるのだ"
        case .door(6): "いちばん奥の扉 ── 大きなかぎ穴が二つあるのだ"
        case .door: "扉 ── 札に、注文が書いてあるのだ"
        case .doorway: "扉の裏側"
        case .station(.mirror): "鏡とブラシ ── 長い柄のついたブラシが置いてあるのだ"
        case .station(.stand): "黒い台 ── 何かを置く台なのだ"
        case .station(.hooks): "釘 ── 帽子や外套をかけるところなのだ"
        case .station(.safe): "金庫 ── 口を開けて、鍵まで添えてあるのだ"
        case .station(.cream): "硝子の壺 ── 牛乳のクリームが入っているのだ"
        case .station(.creamSmall): "ちいさな壺 ── ここにもクリームなのだ"
        case .station(.perfume): "香水の瓶 ── 金ピカなのだ"
        case .station(.salt): "塩壺 ── 立派な青い瀬戸の塩壺なのだ"
        case .signboard: "看板 ──「RESTAURANT 西洋料理店 WILDCAT HOUSE 山猫軒」"
        }
    }

    var actionTitle: String {
        switch self {
        case .door: "よむ"
        case .signboard: "よむ"
        case .station(.cream), .station(.creamSmall): "ぬる"
        case .station(.perfume): "ふる"
        case .station(.mirror): "つかう"
        case .station: "しらべる"
        case .doorway: "しらべる"
        }
    }

    var triggersOnEnter: Bool {
        if case .doorway = self { return true }
        return false
    }
}

/// 兄弟の読み合わせの進み具合（ジロの姿がどれだけはっきりしたか）
@Observable
final class ReadAlongProgress {
    static let total = 7
    fileprivate(set) var count = 0
}

/// 『注文の多い料理店』の本の中。すすき原の山猫軒の玄関から、注文の札がかかった扉を順に抜けていく。
/// 食いしん坊の兄弟（タイチとジロ）がずんだもんのうしろについてくる
final class YamanekoScene: WalkScene<YamanekoInteractable> {
    let progress = ReadAlongProgress()
    /// 札を読み合わせた扉
    private(set) var readDoors: Set<Int> = []
    private(set) var openedDoors: Set<Int> = []
    private(set) var doneStations: Set<YamanekoStation> = []
    /// 裏側の注文を読んだ扉
    private(set) var passedDoorways: Set<Int> = []

    private let taichi = SKSpriteNode()
    private let jiro = SKSpriteNode()
    private var doorNodes: [SKSpriteNode] = []
    private var doorObstacles: [Int] = []
    private var stationNodes: [YamanekoStation: SKSpriteNode] = [:]

    /// 扉の行（玄関から奥へ）
    static let doorRows: [CGFloat] = [35, 30, 25, 20, 15, 10, 4]

    init() {
        super.init(columns: 10, rows: 42, playerStart: (4.5, 39.6))
        backgroundColor = SKColor(red: 0.42, green: 0.52, blue: 0.34, alpha: 1)
    }

    override func buildMap() {
        buildOutside()
        buildCorridor()
        buildDoors()
        buildStations()
        buildParty()
    }

    // MARK: - Map

    private func buildOutside() {
        for row in 36..<rows {
            for column in 0..<columns {
                let grass = "melos_grass_\((row * 5 + column * 3) % 3)"
                place((4...5).contains(column) ? "melos_road_\(row % 2)" : grass, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for row in 36..<rows {
            place("yama_susuki", column: 0, row: CGFloat(row), z: -9_000)
            place("yama_susuki", column: CGFloat(columns - 1), row: CGFloat(row), z: -9_000)
        }
        for column in [1, 2, 7, 8] {
            place("yama_susuki", column: CGFloat(column), row: 40.6)
        }
        place("yama_signboard", column: 6.2, row: 36.4)
        addObstacle(column: 6.4, row: 37.0, width: 1.6, height: 0.4)
        addZone(column: 6, row: 37.4, width: 2.2, height: 1.2, interactable: .signboard, anchor: (7.2, 35.9))
        addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
        addObstacle(column: 0, row: 40.8, width: 3, height: 1)
        addObstacle(column: 7, row: 40.8, width: 3, height: 1)
    }

    private func buildCorridor() {
        for row in 0..<36 {
            for column in 1..<(columns - 1) {
                let name = (4...5).contains(column) ? "yama_carpet" : "yama_floor_\((row + column) % 2)"
                place(name, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
            place("yama_side", column: 0, row: CGFloat(row), z: -9_000)
            place("yama_side", column: CGFloat(columns - 1), row: CGFloat(row), z: -9_000)
        }
        for row in 0..<4 {
            for column in 1..<(columns - 1) {
                place("yama_wall", column: CGFloat(column), row: CGFloat(row), z: -9_000)
            }
        }
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 4.3)
        addObstacle(column: 0, row: 0, width: 1, height: 36)
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: 36)
    }

    private func buildDoors() {
        for (index, row) in Self.doorRows.enumerated() {
            let wall = index == 0 ? "yama_brick" : "yama_wall"
            for column in 1..<(columns - 1) where !(4...5).contains(column) {
                place(wall, column: CGFloat(column), row: row, z: -9_000)
            }
            if index == 0 {
                place("yama_brick", column: 0, row: row, z: -9_000)
                place("yama_brick", column: CGFloat(columns - 1), row: row, z: -9_000)
            }
            addObstacle(column: 0, row: row, width: 4, height: 1)
            addObstacle(column: 6, row: row, width: 4, height: 1)
            let name = index == 6 ? "yama_door_last_0" : "yama_door_\(index)"
            let door = place(name, column: 4, row: row, z: -9_000)
            if index == 6 {
                let eyes = [Self.texture("yama_door_last_0"), Self.texture("yama_door_last_1")]
                door.run(.repeatForever(.animate(with: eyes, timePerFrame: 0.7)))
                door.isPaused = true
            }
            doorNodes.append(door)
            doorObstacles.append(addObstacle(column: 4, row: row, width: 2, height: 1))
            if index < 6 {
                // 扉を抜けた先で、裏側の注文を読む
                addZone(column: 4, row: row - 1.4, width: 2, height: 1.2, interactable: .doorway(index), anchor: (5, row - 1.6))
            }
            addZone(column: 4, row: row + 1, width: 2, height: 1.3, interactable: .door(index), anchor: (5, row - 0.2))
        }
    }

    private func buildStations() {
        // 部屋（扉の行の下の4行）の左右の壁ぎわに置く
        func room(_ index: Int) -> CGFloat { Self.doorRows[index] + 1 }
        addStation(.mirror, sprite: "yama_mirror", column: 1.2, row: room(2) + 0.4, size: (1, 1))
        addStation(.stand, sprite: "yama_stand", column: 1.2, row: room(3) + 1.0, size: (2, 1))
        addStation(.hooks, sprite: "yama_hooks", column: 6.8, row: room(3) + 0.2, size: (2, 1))
        addStation(.safe, sprite: "yama_safe", column: 1.4, row: room(4) + 0.6, size: (1, 1))
        addStation(.cream, sprite: "yama_cream", column: 7.4, row: room(4) + 1.2, size: (1, 1))
        addStation(.creamSmall, sprite: "yama_cream_small", column: 1.6, row: room(5) + 1.2, size: (1, 1))
        addStation(.perfume, sprite: "yama_perfume", column: 7.4, row: room(5) + 1.2, size: (1, 1))
        addStation(.salt, sprite: "yama_salt", column: 2.0, row: room(6) + 1.4, size: (1, 1))
    }

    private func addStation(_ station: YamanekoStation, sprite: String, column: CGFloat, row: CGFloat, size: (width: CGFloat, height: CGFloat)) {
        let node = place(sprite, column: column, row: row)
        stationNodes[station] = node
        let isLeft = column < 4
        addObstacle(column: column + 0.1, row: row + size.height - 0.4, width: size.width - 0.2, height: 0.4)
        let zoneColumn = isLeft ? column + size.width - 0.2 : column - 1.4
        addZone(
            column: zoneColumn, row: row + size.height - 0.9, width: 1.6, height: 1.4,
            interactable: .station(station), anchor: (column + size.width / 2, row - 0.6)
        )
    }

    private func buildParty() {
        for (ghost, name) in [(taichi, "brother_elder"), (jiro, "brother_younger")] {
            let frames = [Self.texture("\(name)_0"), Self.texture("\(name)_1")]
            ghost.texture = frames[0]
            ghost.size = CGSize(width: 16, height: 16)
            ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
            ghost.run(.repeatForever(.animate(with: frames, timePerFrame: 0.45)))
            addToWorld(ghost)
        }
        taichi.alpha = 0.85
        updateJiro()
        // ジロは、ときどき消えかかる
        jiro.run(.repeatForever(.sequence([
            .wait(forDuration: 2.5, withRange: 2),
            .fadeAlpha(by: -0.25, duration: 0.3),
            .fadeAlpha(by: 0.25, duration: 0.5),
        ])), withKey: "flicker")
        setFollowers([taichi, jiro])
    }

    private func updateJiro() {
        jiro.alpha = 0.3 + 0.55 * CGFloat(progress.count) / CGFloat(ReadAlongProgress.total)
    }

    // MARK: - 扉と注文

    /// 兄弟が札を読み合わせた。ジロの姿が少しはっきりする
    func markRead(_ door: Int) {
        guard readDoors.insert(door).inserted else { return }
        progress.count = readDoors.count
        updateJiro()
        if progress.count >= ReadAlongProgress.total {
            jiro.removeAction(forKey: "flicker")
            jiro.run(.fadeAlpha(to: 0.85, duration: 0.6))
        }
    }

    /// この扉を開けるのに、手前の部屋でまだやっていない注文
    func pendingStations(before door: Int) -> [YamanekoStation] {
        YamanekoStation.allCases.filter { $0.room == door && !doneStations.contains($0) }
    }

    func complete(_ station: YamanekoStation) {
        doneStations.insert(station)
        switch station {
        case .hooks: stationNodes[station]?.texture = Self.texture("yama_hooks_filled")
        case .safe: stationNodes[station]?.texture = Self.texture("yama_safe_closed")
        default: break
        }
    }

    func openDoor(_ index: Int) {
        guard openedDoors.insert(index).inserted else { return }
        doorNodes[index].texture = Self.texture("yama_door_open")
        removeObstacle(doorObstacles[index])
    }

    func passDoorway(_ index: Int) -> Bool {
        passedDoorways.insert(index).inserted
    }

    /// うしろの戸が、もう一分も動かなくなる
    func lockBehind(_ index: Int) {
        doorNodes[index].texture = Self.texture("yama_door_\(index)")
        doorObstacles[index] = addObstacle(column: 4, row: Self.doorRows[index], width: 2, height: 1)
    }

    /// かぎ穴から、青い眼玉がきょろきょろのぞく
    func showEyes() {
        doorNodes[6].isPaused = false
    }

    /// 白熊のような犬が二疋、扉をつきやぶって飛び込んでくる
    func dogsBurstIn() async {
        doorNodes[6].isPaused = true
        doorNodes[6].texture = Self.texture("yama_door_0")
        let frames = [Self.texture("yama_dog_0"), Self.texture("yama_dog_1")]
        let entrance = point(column: 5, row: Self.doorRows[5] + 1)
        var dogs: [SKSpriteNode] = []
        for index in 0..<2 {
            let dog = SKSpriteNode(texture: frames[0])
            dog.anchorPoint = CGPoint(x: 0.5, y: 0)
            dog.position = CGPoint(x: entrance.x + CGFloat(index * 12 - 6), y: entrance.y)
            dog.zPosition = 2_000
            dog.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)), withKey: "frames")
            addToWorld(dog)
            dogs.append(dog)
        }
        // 室の中をくるくる廻って、奥の扉へ吸い込まれる
        let target = point(column: 5, row: Self.doorRows[6] + 1)
        for (index, dog) in dogs.enumerated() {
            dog.run(.sequence([
                .wait(forDuration: Double(index) * 0.15),
                .moveBy(x: -30, y: 16, duration: 0.35),
                .moveBy(x: 50, y: 10, duration: 0.35),
                .moveBy(x: -20, y: 14, duration: 0.3),
                .move(to: target, duration: 0.4),
                .fadeOut(withDuration: 0.2),
            ]), withKey: "run")
        }
        await run(.wait(forDuration: 1.9), on: taichi)
        doorNodes[6].texture = Self.texture("yama_door_open")
    }

    /// 室がけむりのように消え、すすき原に立っている
    func vanishRestaurant() async {
        let fog = SKSpriteNode(color: .white, size: CGSize(width: 4_000, height: 4_000))
        fog.alpha = 0
        fog.zPosition = 9_900
        addToCamera(fog)
        await run(.fadeAlpha(to: 1, duration: 0.8), on: fog)
        placePlayer(column: 4.5, row: 38.6)
        await run(.fadeOut(withDuration: 1.0), on: fog)
        fog.removeFromParent()
    }

    /// 兄弟が笑いころげる
    func brothersLaugh() async {
        for ghost in [taichi, jiro] {
            ghost.run(.sequence([
                .moveBy(x: 0, y: 3, duration: 0.1), .moveBy(x: 0, y: -3, duration: 0.1),
                .moveBy(x: 0, y: 3, duration: 0.1), .moveBy(x: 0, y: -3, duration: 0.1),
            ]), withKey: "laugh")
        }
        await run(.wait(forDuration: 0.5), on: taichi)
    }
}
