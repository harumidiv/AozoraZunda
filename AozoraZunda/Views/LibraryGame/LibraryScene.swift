import SpriteKit

/// 図書館の中で調べられるもの
enum LibraryInteractable: WalkInteractable {
    /// かな行ごとの本棚（label は "あ"〜"わ"）
    case shelf(label: String)
    case librarian
    /// 入口。ずんだもんの部屋に帰る
    case exit

    var prompt: String {
        switch self {
        case .shelf(let label):
            "「\(label)」の棚 ── \(label)行の作家の本が並んでいる"
        case .librarian:
            "司書さん ── 作品名や作家名で本をさがしてくれる"
        case .exit:
            "入口 ── ずんだもんの部屋に帰るのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .shelf: "しらべる"
        case .librarian: "はなす"
        case .exit: "かえる"
        }
    }

    var triggersOnEnter: Bool {
        self == .exit
    }
}

/// 図書館のマップ。キャラクターを歩かせて本棚や司書さんを調べる
final class LibraryScene: WalkScene<LibraryInteractable> {
    private static let shelfLabels = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"]

    init() {
        // 入口のマットの少し上から始める（着いた途端に「かえる」が出ないように）
        super.init(columns: 24, rows: 20, playerStart: (12, 16.6))
    }

    override func buildMap() {
        buildRoom()
        buildFurniture()
        buildLibrarian()
    }

    private func buildRoom() {
        for row in 2..<(rows - 1) {
            for column in 1..<(columns - 1) {
                let variant = (row * 7 + column * 3) % 3
                place("floor_\(variant)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for column in 1..<(columns - 1) {
            place("wall_upper", column: CGFloat(column), row: 0, z: -9_000)
            place("wall_lower", column: CGFloat(column), row: 1, z: -9_000)
        }
        for row in 0..<rows {
            place("wall_side", column: 0, row: CGFloat(row), z: -8_000)
            place("wall_side", column: CGFloat(columns - 1), row: CGFloat(row), z: -8_000)
        }
        // 下の壁の玄関マットの前は入口として空けておく
        let entrance = 11...12
        for column in 1..<(columns - 1) where !entrance.contains(column) {
            place("wall_side", column: CGFloat(column), row: CGFloat(rows - 1), z: 5_000)
        }
        for column in entrance {
            place("floor_0", column: CGFloat(column), row: CGFloat(rows - 1), z: -10_000)
        }
        for column in [3, 8, 14, 19] {
            place("window", column: CGFloat(column), row: 0, z: -8_500)
        }
        place("clock", column: 11.5, row: 0.4, z: -8_500)

        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 2.25)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows - 1), width: CGFloat(columns), height: 1)
    }

    private func buildFurniture() {
        place("rug", column: 10, row: 11, z: -9_500)
        place("doormat", column: 11, row: 18.2, z: -9_500)
        addZone(column: 10.5, row: 17.7, width: 3, height: 1.5, interactable: .exit, anchor: (12, 17.2))

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
            addZone(
                column: slot.column - 0.25, row: slot.row + 1.9, width: 2.5, height: 1.2,
                interactable: .shelf(label: Self.shelfLabels[index]),
                anchor: (slot.column + 1, slot.row - 0.6)
            )
        }

        // 受付カウンター
        place("counter", column: 2, row: 14)
        addObstacle(column: 2, row: 14.5, width: 3, height: 1)
        addZone(column: 1.5, row: 15.4, width: 4, height: 1.8, interactable: .librarian, anchor: (3.5, 12.6))

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

    private func buildLibrarian() {
        let librarian = SKSpriteNode(texture: Self.texture("librarian_idle1"))
        librarian.anchorPoint = CGPoint(x: 0.5, y: 0)
        librarian.position = point(column: 3.5, row: 14.3)
        librarian.zPosition = Self.depth(forBaseY: librarian.position.y)
        addToWorld(librarian)
        let blink = SKAction.sequence([
            .setTexture(Self.texture("librarian_idle1")),
            .wait(forDuration: 2.6, withRange: 1.2),
            .setTexture(Self.texture("librarian_idle2")),
            .wait(forDuration: 0.15),
        ])
        librarian.run(.repeatForever(blink))
    }
}
