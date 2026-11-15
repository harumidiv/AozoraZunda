import SpriteKit

/// 町で調べられるもの
enum TownInteractable: WalkInteractable {
    case person(Townsperson)
    /// ずんだもんの家のドア
    case home
    /// 図書館の入口
    case library
    case signpost

    var prompt: String {
        switch self {
        case .person(.baker): "パン屋のミツさん ── 店先でほうきを持っているのだ"
        case .person(.boy): "ソウタ ── 通りで、のりもの図鑑をながめているのだ"
        case .person(.grandpa): "ゲンさん ── 公園のベンチで日なたぼっこしているのだ"
        case .person(.student): "ユイさん ── 図書館の前で、むずかしい顔をしているのだ"
        case .home: "ずんだもんの家 ── 部屋に帰るのだ"
        case .library: "としょかん ── 本がたくさんあるのだ"
        case .signpost: "道しるべ ──「↑ としょかん　← ずんだもんの家　→ パン屋・公園」"
        }
    }

    var actionTitle: String {
        switch self {
        case .person: "はなす"
        case .home: "かえる"
        case .library: "はいる"
        case .signpost: "よむ"
        }
    }

    var triggersOnEnter: Bool {
        self == .home || self == .library
    }
}

/// 昼の町のマップ。ずんだもんの家と図書館のあいだの通りに、本をさがしている町の人がいる
final class TownScene: WalkScene<TownInteractable> {
    /// どこから町に出てきたか（立つ位置を決める）
    enum Entrance {
        case home, library
    }

    private var people: [Townsperson: SKSpriteNode] = [:]
    private let carriedBook = SKSpriteNode(texture: TownScene.texture("town_carried_book"))
    /// 頼みごとがある人の頭の上に出す「！」
    private var wishMarks: [Townsperson: SKSpriteNode] = [:]

    private static let roadColumns = 12...13
    private static let roadRows = 10...11

    init(entrance: Entrance) {
        let start: (CGFloat, CGFloat) = switch entrance {
        case .home: (6, 18.9)
        case .library: (13, 7.7)
        }
        super.init(columns: 26, rows: 22, playerStart: start)
        backgroundColor = SKColor(red: 0.30, green: 0.52, blue: 0.24, alpha: 1)
    }

    override func buildMap() {
        buildGround()
        buildBuildings()
        buildDecorations()
        buildPeople()
        carriedBook.anchorPoint = CGPoint(x: 0.5, y: 0)
        carriedBook.position = CGPoint(x: 0, y: 17)
        carriedBook.zPosition = 1
        attachToPlayer(carriedBook)
        showCarriedBook(isCarryingBook)
        updateMarks(wishing: wishingPeople, story: storyPerson)
    }

    // MARK: - 地面

    private func buildGround() {
        var paved = Set<[Int]>()
        func pave(columns: ClosedRange<Int>, rows: ClosedRange<Int>) {
            for row in rows { for column in columns { paved.insert([column, row]) } }
        }
        // 図書館から下へのびる大通りと、左右にのびる横道
        pave(columns: Self.roadColumns, rows: 6...21)
        pave(columns: 2...23, rows: Self.roadRows)
        // 家・パン屋・公園への小道
        pave(columns: 5...6, rows: 12...20)
        pave(columns: 21...22, rows: 12...16)
        pave(columns: 14...19, rows: 18...19)

        for row in 0..<rows {
            for column in 0..<columns {
                let name = paved.contains([column, row])
                    ? "town_pave_\((row + column) % 2)"
                    : "town_grass_\((row * 7 + column * 3) % 3)"
                place(name, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for (column, row) in [(3, 8), (9, 13), (16, 14), (23, 12), (2, 19), (24, 19), (10, 20), (17, 3)] {
            place("town_flowers", column: CGFloat(column), row: CGFloat(row), z: -9_900)
        }

        // マップの外へは出られない
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 1)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
    }

    // MARK: - 建物

    private func buildBuildings() {
        // 図書館（8x5マス）。扉は 12〜13 列
        place("town_library", column: 9, row: 1)
        addObstacle(column: 9.2, row: 2.6, width: 7.6, height: 3.4)
        addZone(column: 11.6, row: 5.9, width: 2.8, height: 1.0, interactable: .library, anchor: (13, 3.6))

        // ずんだもんの家（5x4マス）。ドアは 5〜6 列
        place("town_house", column: 3, row: 13)
        addObstacle(column: 3.3, row: 14.6, width: 4.4, height: 2.4)
        addZone(column: 4.6, row: 16.9, width: 2.8, height: 1.0, interactable: .home, anchor: (6, 14.9))

        // パン屋（5x4マス）
        place("town_bakery", column: 18, row: 12)
        addObstacle(column: 18.2, row: 13.2, width: 4.6, height: 2.8)
    }

    private func buildDecorations() {
        // 木（2x2マス）。根元だけぶつかる
        let trees: [(CGFloat, CGFloat)] = [
            (1, 1), (3.5, 0.5), (6, 1.5), (18, 1), (20.5, 0.5), (23, 1.5),
            (0.5, 4.5), (23.5, 5), (0.5, 12.5), (23.5, 9), (9, 15.5), (0.5, 17),
            (23.5, 17.5), (8.5, 19.5), (21, 19.5), (15.5, 20),
        ]
        for (column, row) in trees {
            place("town_tree", column: column, row: row)
            addObstacle(column: column + 0.75, row: row + 1.4, width: 0.5, height: 0.5)
        }

        // 図書館の前の花壇と街灯
        for column in [CGFloat(9.5), 15.5] {
            place("town_flowerbed", column: column, row: 6.4)
            addObstacle(column: column, row: 6.8, width: 2, height: 0.6)
        }
        for column in [CGFloat(11), 14] {
            place("town_lamp", column: column, row: 7.4)
            addObstacle(column: column + 0.35, row: 9.0, width: 0.3, height: 0.3)
        }

        // 家のまわりの柵
        for column in 1...4 {
            place("town_fence", column: CGFloat(column), row: 17.2)
        }
        addObstacle(column: 1, row: 17.6, width: 4, height: 0.5)
        place("town_fence", column: 7, row: 17.2)
        place("town_fence", column: 8, row: 17.2)
        addObstacle(column: 7, row: 17.6, width: 2, height: 0.5)

        // 公園のベンチ
        place("town_bench", column: 15.3, row: 17.6)
        addObstacle(column: 15.3, row: 17.8, width: 2, height: 0.6)

        // 道しるべ
        place("town_signpost", column: 14.2, row: 11.9)
        addObstacle(column: 14.55, row: 12.5, width: 0.3, height: 0.4)
        addZone(column: 14, row: 12.9, width: 1.5, height: 1.0, interactable: .signpost, anchor: (14.7, 10.9))
    }

    // MARK: - 町の人

    private static let spots: [Townsperson: (column: CGFloat, row: CGFloat)] = [
        .baker: (19.5, 16.9),
        .boy: (8, 12.0),
        .grandpa: (17.9, 18.9),
        .student: (16.3, 8.6),
    ]

    private func buildPeople() {
        for person in Townsperson.allCases {
            guard let spot = Self.spots[person] else { continue }
            let node = SKSpriteNode(texture: Self.texture("town_\(person.rawValue)_0"))
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = point(column: spot.column, row: spot.row)
            node.zPosition = Self.depth(forBaseY: node.position.y)
            let frames = [Self.texture("town_\(person.rawValue)_0"), Self.texture("town_\(person.rawValue)_1")]
            node.run(.repeatForever(.sequence([
                .setTexture(frames[0]),
                .wait(forDuration: 2.4, withRange: 1.6),
                .setTexture(frames[1]),
                .wait(forDuration: 0.15),
            ])))

            let shadow = SKSpriteNode(texture: Self.texture("shadow"))
            shadow.position = CGPoint(x: 0, y: 1)
            shadow.zPosition = -1
            node.addChild(shadow)
            addToWorld(node)
            people[person] = node

            addObstacle(column: spot.column - 0.35, row: spot.row - 0.45, width: 0.7, height: 0.45)
            addZone(
                column: spot.column - 1.25, row: spot.row - 0.2, width: 2.5, height: 1.3,
                interactable: .person(person), anchor: (spot.column, spot.row - 1.7)
            )
        }
    }

    /// 印を出す人（マップを作る前に指定されたときは、作ったあとに出す）
    private var wishingPeople: Set<Townsperson> = []
    private var storyPerson: Townsperson?
    private var isCarryingBook = false

    /// 新しい頼みごとがある人・借りた本を待っている人の頭の上に印を出す。
    /// story の人（朝のおつかいの相手）には、ストーリーが進む金色の印を出す
    func updateMarks(wishing: Set<Townsperson>, story: Townsperson? = nil) {
        wishingPeople = wishing
        storyPerson = story
        for person in Townsperson.allCases {
            guard let node = people[person] else { continue }
            if wishing.contains(person) || person == story {
                let textureName = person == story ? "bubble_story" : "bubble"
                if let mark = wishMarks[person] {
                    mark.texture = Self.texture(textureName)
                    continue
                }
                let mark = SKSpriteNode(texture: Self.texture(textureName))
                mark.anchorPoint = CGPoint(x: 0.5, y: 0)
                mark.position = CGPoint(x: 0, y: 16)
                mark.zPosition = 2
                mark.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 1.5, duration: 0.4),
                    .moveBy(x: 0, y: -1.5, duration: 0.4),
                ])))
                node.addChild(mark)
                wishMarks[person] = mark
            } else {
                wishMarks[person]?.removeFromParent()
                wishMarks[person] = nil
            }
        }
    }

    /// 借りた本をずんだもんの頭の上にかかげる
    func showCarriedBook(_ isCarrying: Bool) {
        isCarryingBook = isCarrying
        carriedBook.isHidden = !isCarrying
    }

    /// 本を受け取った人が、うれしそうにぴょんと跳ねる
    func cheer(_ person: Townsperson) async {
        guard let node = people[person] else { return }
        await run(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.12),
            .moveBy(x: 0, y: -4, duration: 0.12),
            .moveBy(x: 0, y: 3, duration: 0.1),
            .moveBy(x: 0, y: -3, duration: 0.1),
        ]), on: node)
    }
}
