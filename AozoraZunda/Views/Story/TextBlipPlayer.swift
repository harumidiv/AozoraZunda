import AVFoundation

/// 文字が流れるときの「ピピピ」という音。昔のゲーム機のような矩形波をその場で作って鳴らす
final class TextBlipPlayer {
    static let shared = TextBlipPlayer()

    /// 話し手ごとの声の高さ
    enum Voice: CaseIterable {
        case zunda
        case fumi
        case unknown
        case child
        case taku
        case melos
        case tama
        case mikeko
        case sachi
        case author
        case narration

        /// 基本の高さ（Hz）
        fileprivate var frequency: Double {
            switch self {
            case .zunda: 1_046.5  // ド（C6）
            case .fumi: 784.0  // ソ（G5）
            case .unknown: 659.3  // ミ（E5）
            case .child: 1_318.5  // ミ（E6）
            case .taku: 880.0  // ラ（A5）
            case .melos: 587.3  // レ（D5）
            case .tama: 987.8  // シ（B5）
            case .mikeko: 1_174.7  // レ（D6）
            case .sachi: 1_108.7  // ド#（C#6）
            case .author: 493.9  // シ（B4）
            case .narration: 523.3  // ド（C5）
            }
        }

        fileprivate var volume: Float {
            self == .narration ? 0.05 : 0.08
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    /// 声ごとに少しずつ高さを変えた音を何種類か作っておき、順番に鳴らして単調にならないようにする
    private var buffers: [Voice: [AVAudioPCMBuffer]] = [:]
    private var nextVariant = 0
    private var isConnected = false

    private init() {
        for voice in Voice.allCases {
            buffers[voice] = [1.0, 1.03, 0.97].compactMap { makeBlip(frequency: voice.frequency * $0, volume: voice.volume) }
        }
    }

    func play(_ voice: Voice) {
        guard let variants = buffers[voice], !variants.isEmpty, prepare() else { return }
        nextVariant = (nextVariant + 1) % variants.count
        // 前の音が残っていても切って鳴らす（速く流れる文字に合わせる）
        player.scheduleBuffer(variants[nextVariant], at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }

    /// エンジンを動かす。読み上げなどで止まっていたら動かし直す
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

    /// 30ミリ秒ほどの、すぐ消える矩形波
    private func makeBlip(frequency: Double, volume: Float) -> AVAudioPCMBuffer? {
        let duration = 0.03
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let period = format.sampleRate / frequency
        let attack = Int(format.sampleRate * 0.002)
        for index in 0..<Int(frameCount) {
            let square: Float = (Double(index).truncatingRemainder(dividingBy: period) < period / 2) ? 1 : -1
            // 出だしのプツッという音を防ぎ、あとは素早く小さくする
            let envelope: Float = index < attack
                ? Float(index) / Float(attack)
                : pow(1 - Float(index - attack) / Float(Int(frameCount) - attack), 2)
            samples[index] = square * envelope * volume
        }
        return buffer
    }
}

extension StorySpeaker {
    var blipVoice: TextBlipPlayer.Voice {
        switch self {
        case .zunda: .zunda
        case .fumi: .fumi
        case .unknown: .unknown
        case .child: .child
        case .taku: .taku
        case .melos, .selinuntius: .melos
        case .tama: .tama
        case .mikeko: .mikeko
        case .sachi: .sachi
        case .author: .author
        case .giovanni, .campanella: .taku
        case .conductor, .birdCatcher, .lighthouseKeeper: .melos
        case .townsperson(.baker): .fumi
        case .townsperson(.boy): .child
        case .townsperson(.grandpa): .author
        case .townsperson(.student): .sachi
        }
    }
}
