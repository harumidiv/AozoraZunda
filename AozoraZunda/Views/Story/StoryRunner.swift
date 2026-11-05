import Observation
import SwiftUI

/// 会話の話し手
enum StorySpeaker {
    case zunda
    case fumi
    /// 名乗る前のおフミさんなど、まだ名前の分からない相手
    case unknown
    case child
    case taku
    case melos
    case selinuntius
    case tama
    case mikeko
    case sachi
    case author
    case giovanni
    case campanella
    case conductor
    case birdCatcher
    case lighthouseKeeper
    /// 昼の町の人
    case townsperson(Townsperson)

    var name: String {
        switch self {
        case .zunda: "ずんだもん"
        case .fumi: "おフミさん"
        case .unknown: "？？？"
        case .child: "まいごの子"
        case .taku: "タク"
        case .melos: "メロス"
        case .selinuntius: "セリヌンティウス"
        case .tama: "タマ"
        case .mikeko: "三毛子"
        case .sachi: "サチ"
        case .author: "作者"
        case .giovanni: "ジョバンニ"
        case .campanella: "カムパネルラ"
        case .conductor: "車掌"
        case .birdCatcher: "鳥捕り"
        case .lighthouseKeeper: "燈台看守"
        case .townsperson(let person): person.name
        }
    }

    /// 名札の文字色
    var color: Color {
        switch self {
        case .zunda: Color(red: 0.62, green: 0.88, blue: 0.45)
        case .fumi: Color(red: 0.78, green: 0.70, blue: 0.95)
        case .unknown: Color(white: 0.8)
        case .child: Color(red: 0.98, green: 0.84, blue: 0.45)
        case .taku: Color(red: 0.62, green: 0.80, blue: 1.0)
        case .melos: Color(red: 1.0, green: 0.62, blue: 0.50)
        case .selinuntius: Color(red: 0.85, green: 0.78, blue: 0.62)
        case .tama: Color(red: 0.98, green: 0.78, blue: 0.55)
        case .mikeko: Color(red: 1.0, green: 0.66, blue: 0.70)
        case .sachi: Color(red: 0.70, green: 0.78, blue: 1.0)
        case .author: Color(red: 0.80, green: 0.80, blue: 0.86)
        case .giovanni, .campanella: Color(red: 0.62, green: 0.86, blue: 0.95)
        case .conductor, .birdCatcher, .lighthouseKeeper: Color(red: 0.90, green: 0.80, blue: 0.55)
        case .townsperson(.baker): Color(red: 1.0, green: 0.70, blue: 0.55)
        case .townsperson(.boy): Color(red: 0.98, green: 0.84, blue: 0.45)
        case .townsperson(.grandpa): Color(red: 0.85, green: 0.78, blue: 0.62)
        case .townsperson(.student): Color(red: 0.70, green: 0.78, blue: 1.0)
        }
    }
}

/// 本に残された書き込みの1行
struct HandwrittenNote {
    let text: String
    /// 別の人の字（おフミさんの字など）。インクの色を変えて見せる
    var isOtherHand = false
}

/// 絵本の1ページ
struct PictureBookPage {
    /// さし絵のアセット名（なければ文字だけのページ）
    var imageName: String?
    var text: String
}

struct PictureBook {
    let title: String
    let pages: [PictureBookPage]
}

/// イベント中に画面に出しているもの
struct StoryScreen: Identifiable {
    enum Kind {
        /// 話し手つきのセリフ
        case line(StorySpeaker, String)
        /// セリフのあとに選択肢を出す
        case choice(StorySpeaker, String, [String])
        /// 黒い画面に出す地の文
        case narration(String)
        /// 章の始まり・終わりの見出し
        case chapterTitle(String, String)
        /// もちものを手に入れた
        case itemGet(StoryItem)
        /// 絵本を読み聞かせる
        case pictureBook(PictureBook)
        /// 本の一節を本のページの見た目で出す。選択肢があれば虫食いの言葉を選ぶ
        case passage(String, [String])
        /// 本の余白の書き込み
        case handwriting([HandwrittenNote])
    }

    let id = UUID()
    let kind: Kind
}

/// 会話や演出を順番に進める。イベントは async 関数として書き、
/// `await runner.say(...)` のようにプレイヤーがタップして読み進めるまで待つ
@Observable
final class StoryRunner {
    private(set) var screen: StoryScreen?
    private(set) var isRunning = false
    /// 画面全体を暗転させる
    private(set) var isBlackedOut = false
    /// 本の一節を見せるときに添える出典（「『走れメロス』太宰治」など）
    var passageSource = ""
    private var continuation: CheckedContinuation<Int, Never>?

    /// イベントを始める。ほかのイベント中なら何もしない
    func run(_ script: @escaping () async -> Void) {
        guard !isRunning else { return }
        isRunning = true
        Task {
            await script()
            screen = nil
            isRunning = false
        }
    }

    func say(_ speaker: StorySpeaker, _ text: String) async {
        _ = await present(.line(speaker, text))
    }

    /// 選択肢を出し、選ばれた番号を返す
    func choose(_ speaker: StorySpeaker, _ text: String, _ options: [String]) async -> Int {
        await present(.choice(speaker, text, options))
    }

    func narrate(_ text: String) async {
        _ = await present(.narration(text))
    }

    func chapterTitle(_ title: String, _ subtitle: String) async {
        _ = await present(.chapterTitle(title, subtitle))
    }

    func showItemGet(_ item: StoryItem) async {
        _ = await present(.itemGet(item))
    }

    func readPictureBook(_ book: PictureBook) async {
        _ = await present(.pictureBook(book))
    }

    /// 本の一節を見せる
    func quote(_ text: String) async {
        _ = await present(.passage(text, []))
    }

    /// 本の余白の書き込みを見せる
    func showHandwriting(_ notes: [HandwrittenNote]) async {
        _ = await present(.handwriting(notes))
    }

    /// 虫食いの一節を見せ、選んだ言葉の番号を返す
    func fillInBlank(_ text: String, _ options: [String]) async -> Int {
        await present(.passage(text, options))
    }

    /// 画面を暗転させる・明るくする
    func blackOut(_ isOn: Bool, duration: TimeInterval = 0.6) async {
        screen = nil
        withAnimation(.easeInOut(duration: duration)) {
            isBlackedOut = isOn
        }
        await wait(duration)
    }

    /// 最初から暗転した状態にしておく（画面を開いた直後にイベントを始めるとき）
    func setBlackedOut(_ isOn: Bool) {
        isBlackedOut = isOn
    }

    func wait(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// 画面に出しているものを閉じて、イベントの続きに進む
    func proceed(choosing index: Int = 0) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: index)
    }

    private func present(_ kind: StoryScreen.Kind) async -> Int {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            screen = StoryScreen(kind: kind)
        }
    }
}
