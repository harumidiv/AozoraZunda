import SpriteKit
import SwiftUI

/// ずんだもんの部屋で調べられるもの
enum RoomInteractable: WalkInteractable {
    case shelf(bookCount: Int)
    case desk
    case bed
    case door

    var prompt: String {
        switch self {
        case .shelf(0): "ずんだもんの本棚 ── からっぽなのだ…図書館で借りてくるのだ"
        case .shelf(let count) where count <= 3: "ずんだもんの本棚 ── まだ\(count)冊しかないのだ。すかすかなのだ"
        case .shelf(let count): "ずんだもんの本棚 ── \(count)冊並んでいるのだ"
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
    /// 本棚に並べる本（調べる前から冊数が分かるよう、1冊ずつ描く）
    private var shelfBooks: [CatalogBook] = []
    private let shelfBookLayer = SKNode()
    private var shelfNode: SKSpriteNode?

    /// startsAtDoor: 図書館から帰ってきたときは、ドアの少し内側から始める（着いた途端に「でかける」が出ないように）
    init(startsAtDoor: Bool = false) {
        super.init(columns: 12, rows: 11, playerStart: startsAtDoor ? (6, 8.3) : (6, 7))
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

        // 本棚（空の本棚に持っている本を描き足す）
        let shelf = place("bookshelf_empty", column: 1.5, row: 1)
        shelfNode = shelf
        shelfBookLayer.zPosition = shelf.zPosition + 1
        addToWorld(shelfBookLayer)
        drawShelfBooks()
        addObstacle(column: 1.5, row: 2, width: 2, height: 1)
        addZone(
            column: 1.25, row: 2.9, width: 2.5, height: 1.2,
            interactable: .shelf(bookCount: shelfBooks.count), anchor: (2.5, 0.4)
        )

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

    /// 本棚に並べる本を差し替える。シーンを表示する前に呼んでもよい
    func showBooks(_ books: [CatalogBook]) {
        shelfBooks = books
        replaceInteractable(where: { if case .shelf = $0 { true } else { false } }, with: .shelf(bookCount: books.count))
        drawShelfBooks()
    }

    /// 本棚のドット絵（32x32）の3つの段に、1冊ずつ小さな背表紙を並べる。入りきらない分は描かない
    private func drawShelfBooks() {
        guard let shelfNode else { return }
        shelfBookLayer.removeAllChildren()
        let shelfBottoms: [CGFloat] = [10, 19, 28]
        let innerLeft: CGFloat = 2
        let innerRight: CGFloat = 30
        var shelf = 0
        var x = innerLeft
        for book in shelfBooks {
            let seed = book.spineSeed
            let width: CGFloat = [3, 3, 4][seed % 3]
            let height: CGFloat = [5, 6, 6, 7][seed / 3 % 4]
            if x + width > innerRight {
                shelf += 1
                x = innerLeft
            }
            guard shelf < shelfBottoms.count else { break }
            let color = UIColor(ShelfPalette.spine(for: book).color)
            let top = CGPoint(
                x: shelfNode.position.x + x,
                y: shelfNode.position.y - (shelfBottoms[shelf] - height + 1)
            )
            shelfBookLayer.addChild(pixelRect(color: color, at: top, width: width - 1, height: height))
            // 右端を1ドット暗くして厚みを出す
            let shade = color.darker
            shelfBookLayer.addChild(pixelRect(color: shade, at: CGPoint(x: top.x + width - 1, y: top.y), width: 1, height: height))
            x += width
        }
    }

    /// 左上を基準にした、1ドット単位の四角
    private func pixelRect(color: UIColor, at topLeft: CGPoint, width: CGFloat, height: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = topLeft
        return node
    }
}

private extension UIColor {
    var darker: UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.72, alpha: alpha)
    }
}
