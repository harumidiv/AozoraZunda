import AVFoundation
import Observation
import UIKit

/// 読み上げる本のページ（読書画面のページめくりビューが実装する）
protocol ReadAloudPageSource: AnyObject {
    /// いま開いているページ
    var currentPageIndex: Int { get }
    /// 分割済みのページ数
    var availablePageCount: Int { get }
    /// 最後のページまで分割し終えているか
    var isPaginationComplete: Bool { get }
    func speechText(atPage index: Int) -> String
    /// 読み上げに合わせてページをめくる
    func showPage(_ index: Int)
}

/// ずんだもんの声で本を読み上げる。今のページから1文ずつ読み、ページの終わりで自動でめくる
@Observable
final class ReadAloudController: NSObject {
    enum State: Equatable {
        case idle
        /// 最初の文を合成している（初回は音声モデルの読み込みもあるので少し待つ）
        case preparing
        case speaking
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var style = ZundaStyle.normal
    @ObservationIgnored weak var source: ReadAloudPageSource?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackContinuation: CheckedContinuation<Void, Never>?

    /// 1回に合成する長さの上限。長すぎると合成に時間がかかって間が空く
    private static let maxSentenceLength = 120

    var isActive: Bool {
        state == .preparing || state == .speaking
    }

    func start(style: ZundaStyle) {
        guard let source else { return }
        stop()
        self.style = style
        state = .preparing
        activateAudioSession()
        UIApplication.shared.isIdleTimerDisabled = true
        let startPage = source.currentPageIndex
        task = Task { [weak self] in
            await self?.read(from: startPage)
        }
    }

    /// 声を変えたり、手でページをめくったりしたときに、今のページから読み直す
    func restart(style: ZundaStyle? = nil) {
        guard isActive else { return }
        start(style: style ?? self.style)
    }

    func stop() {
        task?.cancel()
        task = nil
        player?.stop()
        player = nil
        finishPlayback()
        if isActive {
            state = .idle
        }
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - 読み上げの流れ

    private struct Utterance {
        let page: Int
        let text: String
    }

    private func read(from startPage: Int) async {
        let utterances = UtteranceQueue(page: startPage)
        var shownPage = startPage
        var next = await utterances.next(from: source).map { ($0, synthesize($0)) }
        do {
            while let (utterance, audio) = next {
                let data = try await audio.value
                try Task.checkCancellation()
                // 再生している間に次の文を合成しておく
                next = await utterances.next(from: source).map { ($0, synthesize($0)) }
                if utterance.page != shownPage {
                    source?.showPage(utterance.page)
                    shownPage = utterance.page
                }
                state = .speaking
                try await play(data)
            }
            stop()
        } catch is CancellationError {
            next?.1.cancel()
        } catch {
            stop()
            state = .failed(error.localizedDescription)
        }
    }

    private func synthesize(_ utterance: Utterance) -> Task<Data, Error> {
        let style = style
        return Task.detached {
            try await ZundaVoiceEngine.shared.synthesize(utterance.text, style: style)
        }
    }

    /// 開始ページから順に、ページを文に分けて返す
    private final class UtteranceQueue {
        private var page: Int
        private var pending: [String] = []

        init(page: Int) {
            self.page = page
        }

        /// 次に読む文。まだ分割されていないページに来たら、分割が進むのを待つ。最後まで読んだら nil
        func next(from source: ReadAloudPageSource?) async -> Utterance? {
            while pending.isEmpty {
                guard let source, !Task.isCancelled else { return nil }
                if page < source.availablePageCount {
                    pending = ReadAloudController.sentences(in: source.speechText(atPage: page))
                    if pending.isEmpty { page += 1 }
                } else if source.isPaginationComplete {
                    return nil
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
            let utterance = Utterance(page: page, text: pending.removeFirst())
            if pending.isEmpty { page += 1 }
            return utterance
        }
    }

    /// 句点や改行で文に分ける。読む文字のない記号だけの部分は飛ばす
    static func sentences(in text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains(where: { $0.isLetter || $0.isNumber }) {
                sentences.append(contentsOf: split(trimmed))
            }
            current = ""
        }
        for character in text {
            if character.isNewline {
                flush()
                continue
            }
            current.append(character)
            if "。！？!?」』".contains(character) {
                flush()
            }
        }
        flush()
        return sentences
    }

    /// 長すぎる文は読点で区切る
    private static func split(_ sentence: String) -> [String] {
        guard sentence.count > maxSentenceLength else { return [sentence] }
        var parts: [String] = []
        var current = ""
        for character in sentence {
            current.append(character)
            if current.count >= maxSentenceLength || ("、，,".contains(character) && current.count >= maxSentenceLength / 2) {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    // MARK: - 再生

    private func play(_ data: Data) async throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        self.player = player
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                playbackContinuation = continuation
                if !player.play() {
                    finishPlayback()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.player?.stop()
                self?.finishPlayback()
            }
        }
        try Task.checkCancellation()
    }

    private func finishPlayback() {
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }
}

extension ReadAloudController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishPlayback()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.finishPlayback()
        }
    }
}
