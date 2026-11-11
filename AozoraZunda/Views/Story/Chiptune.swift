import Foundation

/// 昔のゲーム機のような音楽を、楽譜からその場で作るための部品。
/// 音のファイルは使わず、矩形波・三角波・ノイズ（とピアノに似せた音）を足し合わせて1曲ぶんの波形にする

/// 音色
nonisolated enum ChiptuneWave {
    /// 矩形波。数字は「山」の割合（0.125・0.25・0.5 で音の感じが変わる）
    case pulse(Double)
    /// ファミコンのような、段々になった三角波（ベースなどに使う）
    case triangle
    /// 倍音を重ねて、ポーンと減っていくピアノに似せた音
    case piano
}

/// 1つのパートの鳴らし方
nonisolated struct ChiptuneVoice {
    var wave: ChiptuneWave
    var volume: Float
    /// 音符の長さのうち、鳴らしている割合（小さいほど歯切れよく）
    var gate: Double = 0.9
    /// 0 でなければ、だいたいこの秒数で音が小さくなっていく（オルゴールやピアノのように）
    var decay: Double = 0
    /// 音符が終わってから消えるまでの秒数
    var release: Double = 0.03
}

/// 1曲。4/4拍子で、楽譜の長さは8分音符を1として数える（1小節 = 8）
nonisolated struct ChiptuneSong {
    /// 伴奏のパターン。和音の音の番号（下から 0, 1, 2…。和音の音を使い切ると1オクターブ上へ）を8分音符ごとに並べる。nil は休み
    struct Accompaniment {
        var voice: ChiptuneVoice
        var pattern: [Int?]
        /// 和音のいちばん下の音のオクターブ
        var octave: Int
    }

    /// ベースのパターン（1小節ぶん）
    struct Bass {
        enum Tone {
            case root, fifth, octave
        }

        var voice: ChiptuneVoice
        var pattern: [(step: Int, tone: Tone, length: Int)]
        var octave: Int
    }

    /// 1分間の4分音符の数
    var tempo: Double
    /// 1小節に1つずつのコード名（"Am"、"G7"、"C/E" など）
    var chords: [String]
    /// メロディ。"E5:2 A4 B4 -:2" のように、音名とオクターブ、":" のあとに長さ（省略すると1）。"-" は休み
    var melody: String
    var lead: ChiptuneVoice
    var accompaniment: Accompaniment?
    var bass: Bass?
    /// ドラム。1小節8文字で、k = バスドラム、s = スネア、h = ハイハット、. = 休み。1小節ぶんを繰り返す
    var drums: String?
    var drumVolume: Float = 0.3

    var steps: Int { chords.count * 8 }
}

// MARK: - 楽譜の読み取り

nonisolated struct ChiptuneNote {
    var start: Int
    var length: Int
    /// MIDI の音の番号（A4 = 69）
    var pitch: Int
}

nonisolated enum ChiptuneScore {
    private static let pitchClasses: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    /// "C#5" → 73 のように、音名を MIDI の番号にする
    static func pitch(_ name: Substring) -> Int? {
        guard let letter = name.first, let base = pitchClasses[letter] else { return nil }
        var rest = name.dropFirst()
        var accidental = 0
        while let mark = rest.first, mark == "#" || mark == "b" {
            accidental += mark == "#" ? 1 : -1
            rest = rest.dropFirst()
        }
        guard let octave = Int(rest) else { return nil }
        return (octave + 1) * 12 + base + accidental
    }

    /// メロディの文字列を音符の並びにする。全体の長さも返す
    static func melody(_ text: String) -> (notes: [ChiptuneNote], length: Int) {
        var notes: [ChiptuneNote] = []
        var position = 0
        for token in text.split(whereSeparator: \.isWhitespace) {
            let parts = token.split(separator: ":")
            let length = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
            if parts[0] != "-" {
                if let pitch = pitch(parts[0]) {
                    notes.append(ChiptuneNote(start: position, length: length, pitch: pitch))
                } else {
                    assertionFailure("読めない音名: \(token)")
                }
            }
            position += length
        }
        return (notes, position)
    }

    /// 音名（オクターブなし）を、音の高さの種類（C = 0 〜 B = 11）にする
    private static func pitchClass(_ name: Substring) -> Int? {
        pitch(Substring(name + "4")).map { ($0 % 12 + 12) % 12 }
    }

    /// コード名を、根音からの半音の数の並びと、いちばん下で鳴らす音（"C/E" の E）にする
    static func chord(_ name: String) -> (root: Int, intervals: [Int], bass: Int) {
        let parts = name.split(separator: "/")
        let symbol = parts[0]
        var rootLength = 1
        if symbol.count > 1, ["#", "b"].contains(symbol[symbol.index(after: symbol.startIndex)]) {
            rootLength = 2
        }
        let rootName = symbol.prefix(rootLength)
        let quality = symbol.dropFirst(rootLength)
        let root = pitchClass(rootName) ?? 0
        let intervals: [Int] = switch quality {
        case "m": [0, 3, 7]
        case "7": [0, 4, 7, 10]
        case "maj7": [0, 4, 7, 11]
        case "m7": [0, 3, 7, 10]
        case "dim": [0, 3, 6]
        case "sus4": [0, 5, 7]
        default: [0, 4, 7]
        }
        var bass = root
        if parts.count > 1, let bassClass = pitchClass(parts[1]) {
            bass = bassClass
        }
        return (root, intervals, bass)
    }

    /// 曲のすべてのパートを、音符の並びにする
    static func parts(of song: ChiptuneSong) -> [(voice: ChiptuneVoice, notes: [ChiptuneNote])] {
        var parts: [(ChiptuneVoice, [ChiptuneNote])] = []
        let melody = melody(song.melody)
        assert(melody.length == song.steps, "メロディの長さ（\(melody.length)）がコードの小節数（\(song.steps)）と合わない")
        parts.append((song.lead, melody.notes))

        if let accompaniment = song.accompaniment {
            var notes: [ChiptuneNote] = []
            for (bar, name) in song.chords.enumerated() {
                let chord = chord(name)
                let base = (accompaniment.octave + 1) * 12 + chord.root
                for (step, index) in accompaniment.pattern.enumerated() {
                    guard let index else { continue }
                    let count = chord.intervals.count
                    let pitch = base + chord.intervals[index % count] + 12 * (index / count)
                    // 次の音までのばす
                    let next = accompaniment.pattern[(step + 1)...].firstIndex { $0 != nil } ?? accompaniment.pattern.count
                    notes.append(ChiptuneNote(start: bar * 8 + step, length: next - step, pitch: pitch))
                }
            }
            parts.append((accompaniment.voice, notes))
        }

        if let bass = song.bass {
            var notes: [ChiptuneNote] = []
            for (bar, name) in song.chords.enumerated() {
                let chord = chord(name)
                let low = (bass.octave + 1) * 12 + chord.bass
                for beat in bass.pattern {
                    var pitch = low
                    switch beat.tone {
                    case .root: break
                    case .octave: pitch += 12
                    case .fifth:
                        // 根音の5度上の音を、いちばん下の音より上で鳴らす
                        let interval = ((chord.root + 7 - chord.bass) % 12 + 12) % 12
                        pitch += interval == 0 ? 12 : interval
                    }
                    notes.append(ChiptuneNote(start: bar * 8 + beat.step, length: beat.length, pitch: pitch))
                }
            }
            parts.append((bass.voice, notes))
        }
        return parts
    }
}

// MARK: - 波形を作る

nonisolated enum ChiptuneRenderer {
    static let sampleRate = 22_050.0

    /// 1曲ぶんの波形。最後まで鳴らすと最初にきれいにつながる（はみ出した余韻は曲の頭に重ねる）
    static func render(_ song: ChiptuneSong) -> [Float] {
        let stepFrames = sampleRate * 60 / song.tempo / 2
        let total = Int((Double(song.steps) * stepFrames).rounded())
        var output = [Float](repeating: 0, count: total)

        for (voice, notes) in ChiptuneScore.parts(of: song) {
            for note in notes {
                let start = Int((Double(note.start) * stepFrames).rounded())
                let held = Double(note.length) * stepFrames * voice.gate
                addNote(note.pitch, voice: voice, start: start, heldFrames: held, into: &output)
            }
        }

        if let drums = song.drums {
            let pattern = Array(drums)
            var noise = Noise()
            for step in 0..<song.steps {
                let hit = pattern[step % pattern.count]
                let start = Int((Double(step) * stepFrames).rounded())
                addDrum(hit, volume: song.drumVolume, start: start, noise: &noise, into: &output)
            }
        }

        // 曲ごとの聞こえる大きさをそろえる（音が割れない範囲で）
        let peak = output.reduce(0) { max($0, abs($1)) }
        let power = output.reduce(0) { $0 + $1 * $1 } / Float(max(1, output.count))
        if peak > 0, power > 0 {
            let scale = min(0.25 / power.squareRoot(), 0.98 / peak)
            for index in output.indices {
                output[index] *= scale
            }
        }
        return output
    }

    private static func frequency(_ pitch: Int) -> Double {
        440 * pow(2, Double(pitch - 69) / 12)
    }

    private static func addNote(_ pitch: Int, voice: ChiptuneVoice, start: Int, heldFrames: Double, into output: inout [Float]) {
        let frequency = frequency(pitch)
        let release = voice.release * sampleRate
        let length = Int(heldFrames + release)
        let attack = sampleRate * 0.004
        for offset in 0..<length {
            let time = Double(offset) / sampleRate
            let phase = (time * frequency).truncatingRemainder(dividingBy: 1)
            let sample: Double = switch voice.wave {
            case .pulse(let duty):
                (phase < duty ? 1 : -1) * 0.5
            case .triangle:
                // 16段の三角波
                ((4 * abs(phase - 0.5) - 1) * 7.5).rounded() / 7.5
            case .piano:
                piano(time: time, frequency: frequency)
            }
            var envelope = min(1, Double(offset) / attack)
            if voice.decay > 0 {
                envelope *= exp(-time / voice.decay)
            }
            if Double(offset) > heldFrames {
                envelope *= max(0, 1 - (Double(offset) - heldFrames) / release)
            }
            let index = (start + offset) % output.count
            output[index] += Float(sample * envelope) * voice.volume
        }
    }

    /// 高い倍音ほど早く消えるようにして、ピアノの「ポーン」に似せる
    private static func piano(time: Double, frequency: Double) -> Double {
        let amplitudes: [Double] = [1, 0.45, 0.25, 0.14, 0.08, 0.04]
        var sum = 0.0
        for (index, amplitude) in amplitudes.enumerated() {
            let harmonic = Double(index + 1)
            // 少しだけ高めにずらすと、弦の響きらしくなる
            let stretched = frequency * harmonic * (1 + 0.0004 * harmonic * harmonic)
            sum += sin(2 * .pi * stretched * time) * amplitude * exp(-time * 1.2 * harmonic)
        }
        return sum / 1.9
    }

    private static func addDrum(_ hit: Character, volume: Float, start: Int, noise: inout Noise, into output: inout [Float]) {
        let duration: Double
        switch hit {
        case "k": duration = 0.14
        case "s": duration = 0.16
        case "h": duration = 0.04
        default: return
        }
        let length = Int(duration * sampleRate)
        var phase = 0.0
        for offset in 0..<length {
            let time = Double(offset) / sampleRate
            let sample: Double
            switch hit {
            case "k":
                // 低いほうへ落ちていく音
                let frequency = 45 + 110 * exp(-time / 0.025)
                phase += frequency / sampleRate
                sample = sin(2 * .pi * phase) * exp(-time / 0.05)
            case "s":
                sample = (noise.next() * 0.7 + sin(2 * .pi * 190 * time) * 0.3) * exp(-time / 0.045)
            default:
                sample = noise.next() * 0.35 * exp(-time / 0.01)
            }
            let index = (start + offset) % output.count
            output[index] += Float(sample) * volume
        }
    }

    /// 毎回おなじ並びになるノイズ（曲が毎回おなじ音になるように）
    private struct Noise {
        var state: UInt32 = 0x1234_5678

        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(state >> 8) / Double(1 << 23) - 1
        }
    }
}
