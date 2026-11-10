import Observation
import SpriteKit

/// 『吾輩は猫である』の本の中で調べられるもの
enum NekoInteractable: WalkInteractable {
    /// 杉垣のそばの書き込み（最初の1つ）
    case hedgeNote
    /// 書斎で昼寝している主人
    case master
    /// 台所の雑煮の椀
    case zouni
    /// 隣の縁側の三毛子
    case mikeko
    /// 茶の間の火鉢（最後の書き込み）
    case brazier
    case kamado
    case table

    var prompt: String {
        switch self {
        case .hedgeNote: "地面に、鉛筆の書き込みが光っているのだ"
        case .master: "主人 ── 本の上で昼寝しているのだ"
        case .zouni: "雑煮の椀 ── 餅が残っているのだ"
        case .mikeko: "三毛子 ── 隣の家の縁側にいる、きれいな猫なのだ"
        case .brazier: "火鉢 ── ぽかぽかあったかいのだ"
        case .kamado: "かまど ── 大きなお釜がのっているのだ"
        case .table: "ちゃぶ台 ── 湯のみが置いてあるのだ"
        }
    }

    var actionTitle: String {
        switch self {
        case .master, .mikeko: "はなす"
        case .hedgeNote: "よむ"
        case .zouni: "たべる"
        default: "しらべる"
        }
    }
}

/// 拾った書き込みの数。画面右上の目盛りがこれを見る
@Observable
final class NoteProgress {
    static let total = 5
    fileprivate(set) var count = 0
}

/// 『吾輩は猫である』の本の中。苦沙弥先生の家（書斎・茶の間・台所・縁側・庭）を、
/// 猫になったずんだもんがタマと歩き、キヨさんの書き込みを拾っていく
final class NekoScene: WalkScene<NekoInteractable> {
    let progress = NoteProgress()

    private let flags: Set<StoryFlag>
    private let tama = SKSpriteNode()
    private let master = SKSpriteNode()
    private let mikeko = SKSpriteNode()
    private var notes: [NekoInteractable: SKSpriteNode] = [:]

    /// 書き込みの場所と、拾ったら立てる目印
    static let noteFlags: [(NekoInteractable, StoryFlag)] = [
        (.hedgeNote, .chapter2NoteHedge),
        (.master, .chapter2NoteStudy),
        (.zouni, .chapter2NoteKitchen),
        (.mikeko, .chapter2NoteMikeko),
        (.brazier, .chapter2NoteBrazier),
    ]

    init(flags: Set<StoryFlag>) {
        self.flags = flags
        super.init(columns: 18, rows: 18, playerStart: (3.5, 13.4))
        playerSpritePrefix = "zundacat"
        backgroundColor = SKColor(red: 0.24, green: 0.20, blue: 0.16, alpha: 1)
        progress.count = Self.noteFlags.filter { flags.contains($0.1) }.count
    }

    override func buildMap() {
        buildHouse()
        buildGarden()
        buildCharacters()
        buildNotes()
    }

    // MARK: - Map

    private func buildHouse() {
        for row in 1...6 {
            for column in 1...16 {
                let name: String = switch column {
                case 1...5: "neko_tatami_v"
                case 7...11: "neko_tatami_h"
                case 13...16: "neko_doma"
                default: "neko_tatami_h"
                }
                place(name, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for column in 1...12 {
            place("neko_veranda", column: CGFloat(column), row: 7, z: -10_000)
        }
        for column in 13...16 {
            place("neko_doma", column: CGFloat(column), row: 7, z: -10_000)
        }
        // 上の障子と、左右の壁
        for column in 0..<columns {
            place("neko_shoji", column: CGFloat(column), row: 0, z: -9_000)
        }
        for row in 0...7 {
            place("neko_wall", column: 0, row: CGFloat(row), z: -8_000)
            place("neko_wall", column: CGFloat(columns - 1), row: CGFloat(row), z: -8_000)
        }
        // 部屋の仕切り（真ん中だけふすまが開いている）
        for column in [6, 12] {
            for row in [1, 2, 6] {
                place("neko_wall", column: CGFloat(column), row: CGFloat(row), z: -8_000)
            }
            addObstacle(column: CGFloat(column), row: 1, width: 1, height: 2)
            addObstacle(column: CGFloat(column), row: 6, width: 1, height: 1)
            for row in 3...5 {
                place(column == 6 ? "neko_tatami_v" : "neko_doma", column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        addObstacle(column: 0, row: 0, width: CGFloat(columns), height: 1.2)
        addObstacle(column: 0, row: 0, width: 1, height: CGFloat(rows))
        addObstacle(column: CGFloat(columns - 1), row: 0, width: 1, height: CGFloat(rows))

        // 書斎: 文机で昼寝する主人
        master.texture = Self.texture("neko_master_0")
        master.size = CGSize(width: 32, height: 24)
        master.anchorPoint = CGPoint(x: 0, y: 1)
        master.position = point(column: 2, row: 1.8)
        master.zPosition = Self.depth(forBaseY: master.position.y - 24)
        master.run(.repeatForever(.animate(with: [Self.texture("neko_master_0"), Self.texture("neko_master_1")], timePerFrame: 0.9)))
        addToWorld(master)
        addObstacle(column: 2, row: 2.6, width: 2, height: 0.7)
        addZone(column: 1.5, row: 3.4, width: 3, height: 1.4, interactable: .master, anchor: (3, 1.2))

        // 茶の間: ちゃぶ台と火鉢
        place("neko_table", column: 7.5, row: 2.4)
        addObstacle(column: 7.5, row: 3.0, width: 2, height: 0.7)
        addZone(column: 7.25, row: 3.9, width: 2.5, height: 1.2, interactable: .table, anchor: (8.5, 1.9))
        place("neko_brazier", column: 10.3, row: 3.6)
        addObstacle(column: 10.4, row: 4.1, width: 0.8, height: 0.5)
        addZone(column: 9.8, row: 4.7, width: 2, height: 1.3, interactable: .brazier, anchor: (10.8, 3.0))

        // 台所: かまど・御櫃・雑煮の椀
        place("neko_kamado", column: 14.5, row: 0.8)
        addObstacle(column: 14.5, row: 1.8, width: 2, height: 1)
        addZone(column: 14.25, row: 2.8, width: 2.5, height: 1, interactable: .kamado, anchor: (15.5, 0.4))
        place("neko_rice_tub", column: 13.1, row: 2.6)
        addObstacle(column: 13.2, row: 3.1, width: 0.8, height: 0.5)
        place("neko_zouni", column: 14.6, row: 5.0)
        addZone(column: 14.1, row: 5.5, width: 2, height: 1.3, interactable: .zouni, anchor: (15.1, 4.4))
    }

    private func buildGarden() {
        for row in 8..<rows {
            for column in 1..<(columns - 1) {
                let isPath = (3...4).contains(column) && row < 15
                let name = row >= 16 ? "neko_veranda" : (isPath ? "neko_soil" : "melos_grass_\((row * 7 + column * 5) % 3)")
                place(name, column: CGFloat(column), row: CGFloat(row), z: -10_000)
            }
        }
        for row in 8..<rows {
            place("neko_hedge", column: 0, row: CGFloat(row), z: -8_000)
            place("neko_hedge", column: CGFloat(columns - 1), row: CGFloat(row), z: -8_000)
        }
        for (column, row) in [(3.5, 8.4), (3.2, 9.6), (3.7, 10.8), (3.3, 12.0)] {
            place("neko_stone", column: column, row: row, z: -9_800)
        }
        place("melos_tree", column: 9, row: 9)
        addObstacle(column: 9.7, row: 10.6, width: 0.6, height: 0.4)
        place("melos_flowers", column: 12, row: 12, z: -9_800)
        place("melos_flowers", column: 6, row: 13, z: -9_800)

        // 杉垣。右のすき間から隣の家の縁側へ行ける
        for column in 0..<columns where !(14...15).contains(column) {
            place("neko_hedge", column: CGFloat(column), row: 15)
        }
        addObstacle(column: 0, row: 15, width: 14, height: 1)
        addObstacle(column: 16, row: 15, width: 2, height: 1)
        for column in 0..<columns {
            place("neko_shoji", column: CGFloat(column), row: 17, z: -9_000)
        }
        addObstacle(column: 0, row: 17, width: CGFloat(columns), height: 1)
    }

    private func buildCharacters() {
        let tamaFrames = [Self.texture("tama_0"), Self.texture("tama_1")]
        tama.texture = tamaFrames[0]
        tama.size = CGSize(width: 16, height: 16)
        tama.anchorPoint = CGPoint(x: 0.5, y: 0)
        tama.alpha = 0.8
        tama.run(.repeatForever(.animate(with: tamaFrames, timePerFrame: 0.6)))
        addToWorld(tama)
        setFollowers([tama])

        // 隣の家の縁側の三毛子
        mikeko.texture = Self.texture("mikeko_0")
        mikeko.size = CGSize(width: 16, height: 16)
        mikeko.anchorPoint = CGPoint(x: 0.5, y: 0)
        mikeko.position = point(column: 15, row: 17)
        mikeko.zPosition = Self.depth(forBaseY: mikeko.position.y)
        mikeko.run(.repeatForever(.animate(with: [Self.texture("mikeko_0"), Self.texture("mikeko_1")], timePerFrame: 0.7)))
        addToWorld(mikeko)
        addObstacle(column: 14.6, row: 16.5, width: 0.8, height: 0.5)
        addZone(column: 14, row: 15.2, width: 2, height: 1.3, interactable: .mikeko, anchor: (15, 15.8))
    }

    /// まだ拾っていない書き込みのところを光らせる。最後の火鉢は、ほかの4つを拾ってから
    private func buildNotes() {
        let spots: [NekoInteractable: (column: CGFloat, row: CGFloat)] = [
            .hedgeNote: (5.2, 12.8),
            .master: (3.6, 1.6),
            .zouni: (15.6, 4.6),
            .mikeko: (15.8, 16.2),
            .brazier: (11.2, 3.2),
        ]
        for (interactable, flag) in Self.noteFlags where !flags.contains(flag) {
            guard let spot = spots[interactable] else { continue }
            let glow = SKSpriteNode(texture: Self.texture("note_glow_0"))
            glow.position = point(column: spot.column, row: spot.row)
            glow.zPosition = 9_600
            glow.setScale(0.75)
            glow.run(.repeatForever(.animate(with: (0..<3).map { Self.texture("note_glow_\($0)") }, timePerFrame: 0.25)))
            glow.isHidden = interactable == .brazier && progress.count < NoteProgress.total - 1
            addToWorld(glow)
            notes[interactable] = glow
        }
        if !flags.contains(.chapter2NoteHedge) {
            addZone(column: 4.5, row: 12.6, width: 1.5, height: 1.4, interactable: .hedgeNote, anchor: (5.2, 12.0))
        }
    }

    // MARK: - 演出

    /// 書き込みを拾った
    func collectNote(at interactable: NekoInteractable) {
        notes[interactable]?.removeFromParent()
        notes[interactable] = nil
        if interactable == .hedgeNote {
            removeZones { $0 == .hedgeNote }
        }
        progress.count += 1
        // 4つ拾ったら、茶の間の火鉢の書き込みが光り出す
        if progress.count >= NoteProgress.total - 1 {
            notes[.brazier]?.isHidden = false
        }
    }

    /// 雑煮の餅が歯にくっついて、後足で立って踊る
    func danceWithMochi() async {
        let hop = SKAction.sequence([.moveBy(x: 0, y: 3, duration: 0.08), .moveBy(x: 0, y: -3, duration: 0.08)])
        let flip = SKAction.sequence([.scaleX(to: -1, duration: 0), hop, .scaleX(to: 1, duration: 0), hop])
        await runOnPlayer(.repeat(flip, count: 5))
    }

    /// 主人が寝返りを打つ（鼻ちょうちんが割れる）
    func wakeMaster() async {
        await run(.sequence([.moveBy(x: 1, y: 0, duration: 0.06), .moveBy(x: -2, y: 0, duration: 0.06), .moveBy(x: 1, y: 0, duration: 0.06)]), on: master)
    }
}
