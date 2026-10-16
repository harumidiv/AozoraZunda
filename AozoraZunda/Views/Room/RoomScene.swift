import SpriteKit

/// ずんだもんの部屋で調べられるもの
enum RoomInteractable: WalkInteractable {
    case shelf
    case desk
    case bed
    case door

    var prompt: String {
        switch self {
        case .shelf: "ずんだもんの本棚 ── 図書館で借りてきた本が並んでいるのだ"
        case .desk: "机 ── 読みかけの本のつづきを読むのだ"
        case .bed: "ベッド ── ふかふかなのだ"
        case .door: "ドア ── 図書館へ本を借りにいくのだ"
        }
    }

    var actionTitle: String {
        self == .door ? "でかける" : "しらべる"
    }
}

/// ずんだもんの部屋のマップ
final class RoomScene: WalkScene<RoomInteractable> {
    init() {
        super.init(columns: 12, rows: 11, playerStart: (6, 7))
    }

    override func buildMap() {
        buildRoom()
        buildFurniture()
    }

    private func buildRoom() {
        for row in 2..<(rows - 1) {
            for column in 1..<(columns - 1) {
                let variant = (row * 7 + column * 3) % 3
                place("floor_\(variant)", column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for column in 1..<(columns - 1) {
            place("room_wall_upper", column: CGFloat(column), row: 0, z: -9_000)
            place("wall_lower", column: CGFloat(column), row: 1, z: -9_000)
        }
        for row in 0..<rows {
            place("wall_side", column: 0, row: CGFloat(row), z: -8_000)
            place("wall_side", column: CGFloat(columns - 1), row: CGFloat(row), z: -8_000)
        }
        // 下の壁の真ん中はドア（床と玄関マットだけ置いて出入口に見せる）
        for column in 1..<(columns - 1) where !(5...6).contains(column) {
            place("wall_side", column: CGFloat(column), row: CGFloat(rows - 1), z: 5_000)
        }
        for column in 5...6 {
            place("floor_0", column: CGFloat(column), row: CGFloat(rows - 1), z: -10_000)
        }
        place("window", column: 4.5, row: 0, z: -8_500)
        place("clock", column: 7, row: 0.3, z: -8_500)

        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 2.25)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: 0, row: CGFloat(rows - 1) + 0.4, width: CGFloat(columns), height: 0.6)
    }

    private func buildFurniture() {
        place("room_rug", column: 4.5, row: 5, z: -9_500)
        place("doormat", column: 5, row: 9.4, z: -9_500)

        // 本棚
        place("bookshelf_1", column: 1.5, row: 1)
        addObstacle(column: 1.5, row: 2, width: 2, height: 1)
        addZone(column: 1.25, row: 2.9, width: 2.5, height: 1.2, interactable: .shelf, anchor: (2.5, 0.4))

        // 机と椅子
        place("table", column: 8, row: 1.4)
        place("chair", column: 8.5, row: 2.6)
        addObstacle(column: 8, row: 2.4, width: 2, height: 0.6)
        addZone(column: 7.75, row: 3.4, width: 2.5, height: 1.2, interactable: .desk, anchor: (9, 0.9))

        // ベッド
        place("bed", column: 9, row: 5)
        addObstacle(column: 9, row: 5.6, width: 2, height: 2.4)
        addZone(column: 7.4, row: 5.4, width: 1.6, height: 2.6, interactable: .bed, anchor: (10, 4.4))

        // 観葉植物
        place("plant", column: 1, row: 7.6)
        addObstacle(column: 1.2, row: 8.7, width: 0.6, height: 0.4)

        // ドア
        addZone(column: 4.5, row: 9, width: 3, height: 1.4, interactable: .door, anchor: (6, 8.3))
    }
}
