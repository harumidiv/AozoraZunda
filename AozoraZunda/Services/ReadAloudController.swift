import AVFoundation
import MediaPlayer
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

/// ずんだもんの声で本を読み上げる。今のページから1文ずつ読み、ページの終わりで自動でめくる。
/// アプリがバックグラウンドにいても読み続け、ロック画面やコントロールセンターから止めたり再開したりできる
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
    /// ロック画面などに表示する作品名と作家名
    @ObservationIgnored var nowPlayingTitle = ""
    @ObservationIgnored var nowPlayingAuthor = ""

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var playbackContinuation: CheckedContinuation<Void, Never>?
    // 文と文の間も止めずに鳴らし続けて、バックグラウンドでアプリが止められないようにする
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let playerNode = AVAudioPlayerNode()
    @ObservationIgnored private var connectedFormat: AVAudioFormat?
    @ObservationIgnored private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []

    /// 1回に合成する長さの上限。長すぎると合成に時間がかかって間が空く
    private static let maxSentenceLength = 120

    var isActive: Bool {
        state == .preparing || state == .speaking
    }

    override init() {
        super.init()
        engine.attach(playerNode)
        observeAudioSession()
    }

    func start(style: ZundaStyle) {
        guard let source else { return }
        stopReading()
        self.style = style
        state = .preparing
        activateAudioSession()
        registerRemoteCommands()
        updateNowPlaying()
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

    /// 読み上げを止める。ロック画面の表示は残すので、そこから続きを再開できる
    func stop() {
        stopReading()
        updateNowPlaying()
    }

    /// 読書画面を閉じるとき。ロック画面の表示と操作も片付ける
    func shutdown() {
        stopReading()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
        remoteCommandTargets = []
    }

    private func stopReading() {
        task?.cancel()
        task = nil
        playerNode.stop()
        engine.stop()
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
                let buffer = try await audio.value
                try Task.checkCancellation()
                // 再生している間に次の文を合成しておく
                next = await utterances.next(from: source).map { ($0, synthesize($0)) }
                if utterance.page != shownPage {
                    source?.showPage(utterance.page)
                    shownPage = utterance.page
                }
                if state != .speaking {
                    state = .speaking
                    updateNowPlaying()
                }
                try await play(buffer)
            }
            stop()
        } catch is CancellationError {
            next?.1.cancel()
        } catch {
            stop()
            state = .failed(error.localizedDescription)
        }
    }

    private func synthesize(_ utterance: Utterance) -> Task<AVAudioPCMBuffer, Error> {
        let style = style
        return Task.detached {
            let wav = try await ZundaVoiceEngine.shared.synthesize(utterance.text, style: style)
            return try WAVDecoder.buffer(from: wav)
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

    private func play(_ buffer: AVAudioPCMBuffer) async throws {
        try startEngine(format: buffer.format)
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                playbackContinuation = continuation
                playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                    Task { @MainActor in
                        self?.finishPlayback()
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.playerNode.stop()
                self?.finishPlayback()
            }
        }
        try Task.checkCancellation()
    }

    /// エンジンを動かし、プレーヤーを鳴らしっぱなしにしておく（次の文を流し込むまでは無音が流れる）
    private func startEngine(format: AVAudioFormat) throws {
        if connectedFormat != format {
            playerNode.stop()
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            connectedFormat = format
        }
        if !engine.isRunning {
            try engine.start()
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }
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

    // MARK: - 割り込み・イヤホン

    private func observeAudioSession() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init) ?? []
            MainActor.assumeIsolated {
                guard let self else { return }
                switch type {
                case .began:
                    // 電話などが来たら止める。終わったら続きから読む
                    self.wasInterrupted = self.isActive
                    self.stop()
                case .ended:
                    if self.wasInterrupted, options.contains(.shouldResume) {
                        self.start(style: self.style)
                    }
                    self.wasInterrupted = false
                default:
                    break
                }
            }
        })
        notificationObservers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init)
            MainActor.assumeIsolated {
                // イヤホンを外したら、スピーカーから急に鳴り出さないよう止める
                if reason == .oldDeviceUnavailable {
                    self?.stop()
                }
            }
        })
    }

    @ObservationIgnored private var wasInterrupted = false

    // MARK: - ロック画面

    private func registerRemoteCommands() {
        guard remoteCommandTargets.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ action: @escaping (ReadAloudController) -> Void) {
            let target = command.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return .commandFailed }
                    action(self)
                    return .success
                }
            }
            remoteCommandTargets.append((command, target))
        }
        add(center.playCommand) { $0.start(style: $0.style) }
        add(center.pauseCommand) { $0.stop() }
        add(center.togglePlayPauseCommand) { controller in
            if controller.isActive {
                controller.stop()
            } else {
                controller.start(style: controller.style)
            }
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: "ずんだもん（\(style.label)）",
            MPMediaItemPropertyAlbumTitle: nowPlayingAuthor,
            MPNowPlayingInfoPropertyPlaybackRate: isActive ? 1.0 : 0.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = isActive ? .playing : .paused
    }
}

/// VOICEVOX が返す WAV（リニア PCM）を再生用のバッファにする
nonisolated enum WAVDecoder {
    struct InvalidWAV: LocalizedError {
        var errorDescription: String? { "音声データを読み取れませんでした" }
    }

    static func buffer(from data: Data) throws -> AVAudioPCMBuffer {
        let bytes = [UInt8](data)
        guard bytes.count > 12, String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE" else { throw InvalidWAV() }

        func uint16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func uint32(_ offset: Int) -> Int { uint16(offset) | uint16(offset + 2) << 16 }

        var channels = 0, sampleRate = 0, bitsPerSample = 0
        var samples: ArraySlice<UInt8>?
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
            let size = uint32(offset + 4)
            let body = offset + 8
            guard body + size <= bytes.count else { break }
            if id == "fmt " {
                channels = uint16(body + 2)
                sampleRate = uint32(body + 4)
                bitsPerSample = uint16(body + 14)
            } else if id == "data" {
                samples = bytes[body..<body + size]
            }
            offset = body + size + size % 2
        }
        guard let samples, channels > 0, sampleRate > 0, bitsPerSample == 16,
              let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: AVAudioChannelCount(channels))
        else { throw InvalidWAV() }

        let frameCount = samples.count / 2 / channels
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let output = buffer.floatChannelData else { throw InvalidWAV() }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let start = samples.startIndex
        for frame in 0..<frameCount {
            for channel in 0..<channels {
                let index = start + (frame * channels + channel) * 2
                let value = Int16(bitPattern: UInt16(samples[index]) | UInt16(samples[index + 1]) << 8)
                output[channel][frame] = Float(value) / Float(Int16.max)
            }
        }
        return buffer
    }
}
