import AVFoundation
import UIKit

/// ストーリーの曲を流す。曲はその場で波形を作り、ずっと繰り返す。曲を変えるときは小さくしてから切りかえる
final class MusicPlayer {
    static let shared = MusicPlayer()

    /// 文字の「ピピピ」より少し小さめにする
    private static let volume: Float = 0.3
    /// 絵本の読み上げ中などは、さらに小さくする
    private static let duckedVolume: Float = 0.12

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: ChiptuneRenderer.sampleRate, channels: 1)!
    private var buffers: [StoryMusic: AVAudioPCMBuffer] = [:]
    private var isConnected = false
    private var isDucked = false
    /// いま流している（流そうとしている）曲
    private(set) var current: StoryMusic?
    /// 曲を変えるたびに増やす。前の切りかえの途中だったら、そちらはやめる
    private var generation = 0

    private init() {
        let center = NotificationCenter.default
        // 読み上げで音の設定が変わったり、アプリに戻ってきたりすると止まるので、流し直す
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        }
    }

    /// 曲を変える。nil なら止める
    func play(_ music: StoryMusic?) {
        guard music != current else { return }
        current = music
        generation += 1
        let generation = generation
        Task {
            if player.isPlaying {
                await fade(to: 0, duration: 0.5, generation: generation)
            }
            guard generation == self.generation else { return }
            player.stop()
            guard let music, let buffer = await buffer(for: music), generation == self.generation, prepare() else { return }
            player.volume = 0
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            player.play()
            await fade(to: targetVolume, duration: 1.2, generation: generation)
        }
    }

    /// 読み上げの声を聞きやすくするため、しばらく小さくする
    func setDucked(_ isDucked: Bool) {
        self.isDucked = isDucked
        guard player.isPlaying else { return }
        let generation = generation
        Task { await fade(to: targetVolume, duration: 0.4, generation: generation) }
    }

    private var targetVolume: Float { isDucked ? Self.duckedVolume : Self.volume }

    private func fade(to volume: Float, duration: TimeInterval, generation: Int) async {
        let steps = max(1, Int(duration / 0.03))
        let from = player.volume
        for step in 1...steps {
            try? await Task.sleep(for: .seconds(duration / Double(steps)))
            guard generation == self.generation else { return }
            player.volume = from + (volume - from) * Float(step) / Float(steps)
        }
    }

    /// 曲の波形。はじめて流すときに作る（少し時間がかかるので、裏で作る）
    private func buffer(for music: StoryMusic) async -> AVAudioPCMBuffer? {
        if let buffer = buffers[music] { return buffer }
        let samples = await Task.detached(priority: .userInitiated) { ChiptuneRenderer.render(music.song) }.value
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        buffers[music] = buffer
        return buffer
    }

    /// エンジンを動かす
    private func prepare() -> Bool {
        let session = AVAudioSession.sharedInstance()
        // ほかのアプリの音楽を止めず、消音スイッチにも従う。読み上げ中（playback）はそのままにする
        if session.category != .playback {
            try? session.setCategory(.ambient)
        }
        if !isConnected {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isConnected = true
        }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return false
            }
        }
        return true
    }

    /// 止まってしまった曲を、もう一度流す
    private func resume() {
        guard let current, let buffer = buffers[current], !(engine.isRunning && player.isPlaying) else { return }
        guard prepare() else { return }
        player.stop()
        player.volume = targetVolume
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
}
