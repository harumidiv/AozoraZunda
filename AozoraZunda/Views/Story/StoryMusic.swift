import Foundation

/// 場面ごとの曲。どれもこのアプリのために作った曲で、ずっと繰り返して流す
nonisolated enum StoryMusic: CaseIterable {
    /// ずんだもんの部屋
    case room
    /// 昼の町
    case town
    /// 夜の図書室（序章・第5章・終章の図書室、エピローグ）
    case nightLibrary
    /// 第1章『走れメロス』の本の中
    case melos
    /// 第2章『吾輩は猫である』の本の中
    case neko
    /// 第3章『銀河鉄道の夜』の本の中
    case ginga
    /// 第4章『注文の多い料理店』の本の中
    case yamaneko
    /// 終章『手袋を買いに』の本の中
    case tebukuro
    /// 終章、はるとおフミさんに最後まで読み聞かせる場面。ここだけピアノ
    case finalePiano

    var song: ChiptuneSong {
        switch self {
        case .room: Self.roomSong
        case .town: Self.townSong
        case .nightLibrary: Self.nightLibrarySong
        case .melos: Self.melosSong
        case .neko: Self.nekoSong
        case .ginga: Self.gingaSong
        case .yamaneko: Self.yamanekoSong
        case .tebukuro: Self.tebukuroSong
        case .finalePiano: Self.finalePianoSong
        }
    }

    // MARK: - 曲

    /// ずんだもんの部屋。のんびり、ゆるい
    private static let roomSong = ChiptuneSong(
        tempo: 96,
        chords: ["C", "Am", "F", "G", "C", "Am", "Dm7", "G7"],
        melody: """
        E5 G5 E5 C5 D5:2 E5:2
        C5:2 A4:2 -:2 E5 D5
        C5 D5 F5 A5 G5:2 F5:2
        D5:4 B4 C5 D5:2
        E5 G5 C6 G5 A5:2 G5:2
        E5:2 C5:2 A4:2 C5 D5
        F5:2 E5 D5 C5:2 A4:2
        B4 C5 D5 F5 E5:2 -:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.25), volume: 0.38, gate: 0.6, release: 0.06),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.125), volume: 0.13, gate: 0.4),
            pattern: [nil, 1, nil, 2, nil, 1, nil, 2],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.55),
            pattern: [(0, .root, 2), (2, .fifth, 2), (4, .root, 2), (6, .fifth, 2)],
            octave: 2
        ),
        drums: "k.h.s.h.",
        drumVolume: 0.14
    )

    /// 昼の町。お日さまの下を、てくてく歩く
    private static let townSong = ChiptuneSong(
        tempo: 116,
        chords: ["G", "D/F#", "Em", "C", "Am", "D", "G", "D7"],
        melody: """
        G5:2 D5 B4 D5:2 G5 A5
        F#5:2 E5 D5 A4:2 D5:2
        E5 F#5 G5 B5 A5:2 G5:2
        E5:4 -:2 D5 E5
        C5:2 E5 A5 G5:2 E5:2
        F#5 E5 D5 F#5 A5:2 C6:2
        B5:2 A5 G5 D5 E5 G5:2
        A5:2 F#5:2 D5:2 -:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.25), volume: 0.38, gate: 0.75),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.125), volume: 0.14, gate: 0.5, decay: 0.3),
            pattern: [0, 2, 1, 2, 0, 2, 1, 2],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.7),
            pattern: [(0, .root, 2), (2, .fifth, 2), (4, .octave, 2), (6, .fifth, 2)],
            octave: 2
        ),
        drums: "k.hsk.hs",
        drumVolume: 0.16
    )

    /// 雨の夜の図書室。しずかで、ちょっとふしぎ
    private static let nightLibrarySong = ChiptuneSong(
        tempo: 80,
        chords: ["Am", "F", "C", "G", "Am", "F", "Dm", "E"],
        melody: """
        E5:2 A4 B4 C5:2 B4 A4
        A4:3 G4 F4:2 A4:2
        G4:2 C5 D5 E5:2 G5:2
        D5:6 -:2
        E5:2 A5 G5 E5:2 C5 D5
        C5:3 A4 F4:2 C5:2
        D5:2 F5:2 E5 D5 C5 B4
        G#4:6 -:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.25), volume: 0.42, gate: 0.85, release: 0.12),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.125), volume: 0.16, gate: 0.6, decay: 0.35),
            pattern: [0, 1, 2, 3, 2, 1, 2, 1],
            octave: 3
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.95),
            pattern: [(0, .root, 4), (4, .fifth, 4)],
            octave: 2
        )
    )

    /// 日が沈むまでに走る。速くて勇ましい
    private static let melosSong = ChiptuneSong(
        tempo: 150,
        chords: ["Dm", "Bb", "C", "A", "Dm", "Bb", "Gm", "A"],
        melody: """
        D5 D5 F5 A5 D6:3 C6
        Bb5:2 A5 G5 F5:2 D5:2
        E5 E5 G5 C6 E6:3 D6
        C#6:4 A5:2 -:2
        D6:2 A5:2 F5:2 D5:2
        F5 G5 A5 Bb5 D6:2 Bb5:2
        G5 Bb5 D6 G6 F6:2 E6:2
        E6 C#6 A5 E5 A5:4
        """,
        lead: ChiptuneVoice(wave: .pulse(0.25), volume: 0.4, gate: 0.8),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.5), volume: 0.14, gate: 0.35),
            pattern: [nil, 1, nil, 2, nil, 1, nil, 2],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.55, gate: 0.7),
            pattern: [(0, .root, 1), (1, .octave, 1), (2, .root, 1), (3, .octave, 1), (4, .root, 1), (5, .octave, 1), (6, .fifth, 1), (7, .octave, 1)],
            octave: 2
        ),
        drums: "k.hsk.hs"
    )

    /// 猫の目から見た人間たち。とぼけていて、ちょこまかした感じ
    private static let nekoSong = ChiptuneSong(
        tempo: 126,
        chords: ["F", "Dm", "Gm", "C7", "F", "D7", "Gm7", "C7"],
        melody: """
        C5 - A4 C5 F5:2 E5 F5
        D5 - F5 D5 A4:2 -:2
        Bb4 - D5 Bb4 G5:2 F5 E5
        E5 G5 Bb5 G5 E5:2 C5:2
        A5 - F5 A5 C6:2 A5 F5
        F#5 - A5 F#5 D5:2 C5:2
        Bb4 D5 F5 A5 G5:2 Bb4:2
        C5 D5 E5 G5 F5:2 -:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.25), volume: 0.4, gate: 0.5),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.5), volume: 0.12, gate: 0.3),
            pattern: [nil, nil, 1, nil, nil, nil, 2, nil],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.45),
            pattern: [(0, .root, 2), (4, .fifth, 2)],
            octave: 2
        ),
        drums: "k.s.k.s.",
        drumVolume: 0.2
    )

    /// 星の野原を走る汽車。きらきらした分散和音と、ことこと鳴る線路の音
    private static let gingaSong = ChiptuneSong(
        tempo: 100,
        chords: ["E", "C#m", "A", "B", "G#m", "C#m", "A", "B"],
        melody: """
        B4:2 E5:2 G#5:3 F#5
        E5:4 C#5:2 B4:2
        A4:2 C#5:2 E5:2 F#5:2
        D#5:6 -:2
        B5:3 G#5 D#5:4
        E5:2 G#5:2 C#6:4
        B5:2 A5:2 G#5:2 F#5:2
        F#5:6 D#5:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.5), volume: 0.34, gate: 0.9, release: 0.2),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.125), volume: 0.18, gate: 0.5, decay: 0.25),
            pattern: [0, 1, 2, 3, 4, 3, 2, 1],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.95),
            pattern: [(0, .root, 6), (6, .fifth, 2)],
            octave: 2
        ),
        drums: "khhhkhhh",
        drumVolume: 0.12
    )

    /// 山猫軒の、つぎつぎ出てくる扉。あやしくて、ちょっとおかしい
    private static let yamanekoSong = ChiptuneSong(
        tempo: 112,
        chords: ["Em", "Am", "Em", "B7", "Em", "Am", "C", "B7"],
        melody: """
        E5 - G5 - F#5 F5 E5:2
        A4 - C5 - B4 A#4 A4:2
        B4 E5 G5 B5 A#5 A5 G5:2
        F#5:2 D#5:2 B4:2 -:2
        E6 - B5 - G5 - E5:2
        C6 - A5 - E5 - C5:2
        E5 G5 C6 B5 A5 G5 F#5 E5
        D#5:2 F#5:2 A5:2 B5:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.5), volume: 0.34, gate: 0.55),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .pulse(0.25), volume: 0.1, gate: 0.3),
            pattern: [nil, 2, nil, 1, nil, 2, nil, 1],
            octave: 4
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.5, gate: 0.4),
            pattern: [(0, .root, 2), (2, .fifth, 2), (4, .root, 2), (6, .fifth, 2)],
            octave: 2
        ),
        drums: "k.h.s.h.",
        drumVolume: 0.22
    )

    /// 雪あかりの森と町。オルゴールのような子守唄
    private static let tebukuroSong = ChiptuneSong(
        tempo: 84,
        chords: ["G", "Em", "C", "D", "G", "Em", "Am", "D"],
        melody: """
        D5:2 B4:2 D5:2 G5:2
        E5:4 D5:2 B4:2
        C5:2 E5:2 G5:2 E5:2
        D5:6 -:2
        B5:2 A5:2 G5:2 D5:2
        E5:2 G5:2 B5:4
        C6:2 B5:2 A5:2 E5:2
        F#5:4 A5:2 F#5:2
        """,
        lead: ChiptuneVoice(wave: .pulse(0.125), volume: 0.4, gate: 0.95, decay: 0.6, release: 0.25),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.22, gate: 0.9, decay: 0.4, release: 0.2),
            pattern: [0, 2, 3, 2, 1, 2, 3, 2],
            octave: 3
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .triangle, volume: 0.4, gate: 0.95),
            pattern: [(0, .root, 8)],
            octave: 2
        )
    )

    /// 最後まで読み聞かせる場面。ゆっくりしたピアノ
    private static let finalePianoSong = ChiptuneSong(
        tempo: 70,
        chords: [
            "C", "G/B", "Am", "Em/G", "F", "C/E", "Dm7", "G",
            "F", "G", "Em", "Am", "Dm7", "G", "C", "C",
        ],
        melody: """
        E5:3 D5 C5:2 G4:2
        D5:4 B4:2 G4:2
        C5:3 B4 A4:2 E5:2
        G5:6 F5 E5
        F5:3 E5 D5:2 C5:2
        E5:4 G4:2 C5:2
        D5:3 E5 F5:2 A5:2
        G5:6 -:2
        A5:3 G5 F5:2 C5:2
        D5:3 E5 F5:2 G5:2
        E5:3 D5 B4:2 G5:2
        A5:4 C6:2 B5 A5
        F5:3 E5 D5:2 A5:2
        G5:2 F5:2 E5:2 D5:2
        C5:4 E5:2 G5:2
        C6:6 -:2
        """,
        lead: ChiptuneVoice(wave: .piano, volume: 0.5, gate: 1, decay: 1.6, release: 0.35),
        accompaniment: .init(
            voice: ChiptuneVoice(wave: .piano, volume: 0.2, gate: 1, decay: 1.2, release: 0.3),
            pattern: [nil, 2, 3, 4, 5, 4, 3, 2],
            octave: 3
        ),
        bass: .init(
            voice: ChiptuneVoice(wave: .piano, volume: 0.42, gate: 1, decay: 2.0, release: 0.4),
            pattern: [(0, .root, 8)],
            octave: 2
        )
    )
}
