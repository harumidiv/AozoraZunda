import Foundation
import voicevox_core

/// ずんだもんの声の種類（VOICEVOX のスタイル）。rawValue はスタイルID
nonisolated enum ZundaStyle: Int, CaseIterable, Identifiable, Sendable {
    case normal = 3
    case amaama = 1
    case tsuntsun = 7
    case sexy = 5
    case whisper = 22
    case hisohiso = 38
    case herohero = 75
    case namidame = 76

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .normal: "ノーマル"
        case .amaama: "あまあま"
        case .tsuntsun: "ツンツン"
        case .sexy: "セクシー"
        case .whisper: "ささやき"
        case .hisohiso: "ヒソヒソ"
        case .herohero: "ヘロヘロ"
        case .namidame: "なみだめ"
        }
    }

    /// このスタイルが入っている音声モデルファイル（アプリに同梱しているのはずんだもんを含む3つだけ）
    fileprivate var modelFileName: String {
        switch self {
        case .normal, .amaama, .tsuntsun, .sexy: "0"
        case .whisper, .hisohiso: "5"
        case .herohero, .namidame: "15"
        }
    }
}

nonisolated struct ZundaVoiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }

    fileprivate init(_ message: String) {
        self.message = message
    }

    fileprivate init(_ step: String, code: Int32) {
        message = "\(step)に失敗しました（\(String(cString: voicevox_error_result_to_message(code)))）"
    }
}

/// VOICEVOX でずんだもんの声を合成する。
/// 初期化と合成は重いので専用のキューで1つずつ行い、音声モデルは選んだ声の入ったファイルだけを読み込む
nonisolated final class ZundaVoiceEngine: @unchecked Sendable {
    static let shared = ZundaVoiceEngine()

    private typealias ModelID = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    private let queue = DispatchQueue(label: "ZundaVoiceEngine", qos: .userInitiated)
    // 以下は queue の上でだけ触る
    private var synthesizer: OpaquePointer?
    private var loadedModel: (fileName: String, id: ModelID)?

    private init() {}

    /// 文章を WAV データにする
    func synthesize(_ text: String, style: ZundaStyle) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try self.synthesizeOnQueue(text, style: style) })
            }
        }
    }

    private func synthesizeOnQueue(_ text: String, style: ZundaStyle) throws -> Data {
        let synthesizer = try prepareSynthesizer()
        try loadModel(named: style.modelFileName, into: synthesizer)

        var length: UInt = 0
        var wav: UnsafeMutablePointer<UInt8>?
        let code = text.withCString { text in
            voicevox_synthesizer_tts(synthesizer, text, VoicevoxStyleId(style.rawValue), voicevox_make_default_tts_options(), &length, &wav)
        }
        guard code == 0, let wav else { throw ZundaVoiceError("音声の合成", code: code) }
        defer { voicevox_wav_free(wav) }
        return Data(bytes: wav, count: Int(length))
    }

    /// ONNX Runtime と辞書を読み込んで合成器を作る（最初の1回だけ）
    private func prepareSynthesizer() throws -> OpaquePointer {
        if let synthesizer { return synthesizer }

        var onnxruntime: OpaquePointer? = voicevox_onnxruntime_get()
        var code = voicevox_onnxruntime_init_once(&onnxruntime)
        guard code == 0 else { throw ZundaVoiceError("ONNX Runtime の初期化", code: code) }

        // 辞書ファイルはアプリの中にそのまま入っている（Documents にコピーせず直接読む）
        guard let dictionaryDirectory = Bundle.main.resourcePath else { throw ZundaVoiceError("辞書が見つかりません") }
        var openJTalk: OpaquePointer?
        code = dictionaryDirectory.withCString { voicevox_open_jtalk_rc_new($0, &openJTalk) }
        guard code == 0 else { throw ZundaVoiceError("辞書の読み込み", code: code) }
        // 合成器が辞書を持つので、ここで手放してよい
        defer { voicevox_open_jtalk_rc_delete(openJTalk) }

        var synthesizer: OpaquePointer?
        code = voicevox_synthesizer_new(onnxruntime, openJTalk, voicevox_make_default_initialize_options(), &synthesizer)
        guard code == 0, let synthesizer else { throw ZundaVoiceError("合成器の作成", code: code) }
        self.synthesizer = synthesizer
        return synthesizer
    }

    /// 声に必要な音声モデルを読み込む。メモリを節約するため、別のファイルを使うときは前のものを外す
    private func loadModel(named fileName: String, into synthesizer: OpaquePointer) throws {
        if loadedModel?.fileName == fileName { return }
        if var previous = loadedModel?.id {
            _ = withUnsafePointer(to: &previous) { voicevox_synthesizer_unload_voice_model(synthesizer, $0) }
            loadedModel = nil
        }

        guard let path = Bundle.main.path(forResource: fileName, ofType: "vvm") else {
            throw ZundaVoiceError("音声モデル \(fileName).vvm が見つかりません")
        }
        var model: OpaquePointer?
        var code = path.withCString { voicevox_voice_model_file_open($0, &model) }
        guard code == 0, let model else { throw ZundaVoiceError("音声モデルを開くの", code: code) }
        defer { voicevox_voice_model_file_delete(model) }

        code = voicevox_synthesizer_load_voice_model(synthesizer, model)
        guard code == 0 else { throw ZundaVoiceError("音声モデルの読み込み", code: code) }

        var id: ModelID = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutablePointer(to: &id) { voicevox_voice_model_file_id(model, $0) }
        loadedModel = (fileName, id)
    }
}
