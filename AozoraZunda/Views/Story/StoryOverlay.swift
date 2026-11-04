import SwiftUI

extension Font {
    /// ひと昔前のゲーム風のドット文字（DotGothic16）
    static func pixel(_ size: CGFloat) -> Font {
        .custom("DotGothic16-Regular", size: size)
    }
}

/// ストーリーのイベント中に、セリフ・選択肢・暗転などを画面に重ねて出す
struct StoryOverlay: View {
    let runner: StoryRunner

    var body: some View {
        ZStack {
            if runner.isBlackedOut {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if let screen = runner.screen {
                content(for: screen)
                    .id(screen.id)
            }
        }
        .allowsHitTesting(runner.isRunning)
    }

    @ViewBuilder
    private func content(for screen: StoryScreen) -> some View {
        switch screen.kind {
        case .line(let speaker, let text):
            MessageBox(speaker: speaker, text: text, choices: []) { runner.proceed(choosing: $0) }
        case .choice(let speaker, let text, let choices):
            MessageBox(speaker: speaker, text: text, choices: choices) { runner.proceed(choosing: $0) }
        case .narration(let text):
            NarrationView(text: text) { runner.proceed() }
        case .chapterTitle(let title, let subtitle):
            ChapterTitleView(title: title, subtitle: subtitle) { runner.proceed() }
        case .itemGet(let item):
            ItemGetView(item: item) { runner.proceed() }
        case .pictureBook(let book):
            PictureBookView(book: book) { runner.proceed() }
        case .passage(let text, let options):
            PassageView(source: runner.passageSource, text: text, options: options) { runner.proceed(choosing: $0) }
        }
    }
}

/// 1文字ずつ文字を出す。タップで全文を出し、もう一度タップで次へ進む
private struct TypewriterText: View {
    let text: String
    @Binding var shown: Int
    /// 文字が流れるときに鳴らす音（話し手ごとに高さが違う）
    var voice: TextBlipPlayer.Voice?

    var body: some View {
        // 出ていない部分も透明で描いておき、ウインドウの大きさが途中で変わらないようにする
        let characters = Array(text)
        let visible = String(characters.prefix(shown))
        let hidden = String(characters.dropFirst(shown))
        Text("\(Text(visible))\(Text(hidden).foregroundStyle(.clear))")
            .task(id: text) {
                shown = 0
                while shown < characters.count {
                    try? await Task.sleep(for: .milliseconds(38))
                    if Task.isCancelled || shown >= characters.count { return }
                    shown += 1
                    // 1文字おきに鳴らす。句読点や空白では鳴らさず、間ができるようにする
                    if let voice, shown % 2 == 1, Self.makesSound(characters[shown - 1]) {
                        TextBlipPlayer.shared.play(voice)
                    }
                }
            }
    }

    private static func makesSound(_ character: Character) -> Bool {
        !character.isWhitespace && !"、。…！？「」『』（）・ー〜!?,.".contains(character)
    }
}

/// 名札つきのメッセージウインドウ。選択肢があれば文字を出し終えてから並べる
private struct MessageBox: View {
    let speaker: StorySpeaker
    let text: String
    let choices: [String]
    let proceed: (Int) -> Void

    @State private var shown = 0

    private var isFinished: Bool { shown >= text.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ウインドウの外をタップしても読み進められるようにする
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture(perform: tap)

            VStack(alignment: .leading, spacing: 12) {
                TypewriterText(text: text, shown: $shown, voice: speaker.blipVoice)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                if !choices.isEmpty && isFinished {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(choices.enumerated()), id: \.offset) { index, title in
                            Button {
                                proceed(index)
                            } label: {
                                HStack(spacing: 6) {
                                    // ドット文字のフォントには ▶ がないので記号の画像を使う
                                    Image(systemName: "arrowtriangle.right.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ShelfPalette.highlight)
                                    Text(title)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .font(.pixel(17))
            .lineSpacing(6)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .background(RetroWindowBackground())
            .overlay(alignment: .bottomTrailing) {
                if isFinished && choices.isEmpty {
                    BlinkingCursor()
                        .padding(10)
                }
            }
            .overlay(alignment: .topLeading) {
                Text(speaker.name)
                    .font(.pixel(13))
                    .foregroundStyle(speaker.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(RetroWindowBackground(cornerRadius: 3))
                    .offset(x: 10, y: -14)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: tap)
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
    }

    private func tap() {
        if !isFinished {
            shown = text.count
        } else if choices.isEmpty {
            proceed(0)
        }
    }
}

/// 紺地に白の二重枠の、昔の RPG のようなウインドウ
struct RetroWindowBackground: View {
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(red: 0.08, green: 0.10, blue: 0.26).opacity(0.94))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).inset(by: 1.5).stroke(.white, lineWidth: 3))
            .overlay(RoundedRectangle(cornerRadius: max(0, cornerRadius - 2)).inset(by: 4.5).stroke(Color(white: 0.55), lineWidth: 1))
    }
}

/// 読み進められることを示す ▼
private struct BlinkingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Text("▼")
            .font(.pixel(12))
            .foregroundStyle(.white)
            .opacity(isVisible ? 1 : 0)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(450))
                    isVisible.toggle()
                }
            }
    }
}

/// 黒い画面の真ん中に出す地の文
private struct NarrationView: View {
    let text: String
    let proceed: () -> Void
    @State private var shown = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TypewriterText(text: text, shown: $shown, voice: .narration)
                .font(.pixel(18))
                .lineSpacing(10)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if shown < text.count {
                shown = text.count
            } else {
                proceed()
            }
        }
    }
}

/// 「序章 字を見ると眠いのだ」のような章の見出し
private struct ChapterTitleView: View {
    let title: String
    let subtitle: String
    let proceed: () -> Void
    @State private var isShown = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text(title)
                    .font(.pixel(16))
                    .foregroundStyle(Color(white: 0.7))
                Text(subtitle)
                    .font(.pixel(24))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .opacity(isShown ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: proceed)
        .task {
            withAnimation(.easeIn(duration: 1.0)) { isShown = true }
        }
    }
}

/// 本の一節を、本のページの見た目で見せる。選択肢があれば【　】に入る言葉を選ぶ
private struct PassageView: View {
    let source: String
    let text: String
    let options: [String]
    let proceed: (Int) -> Void

    @State private var isShown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    if !source.isEmpty {
                        Text(source)
                            .font(.pixel(12))
                            .foregroundStyle(Color(red: 0.55, green: 0.42, blue: 0.30))
                    }
                    highlightedText
                        .font(.pixel(17))
                        .lineSpacing(8)
                        .foregroundStyle(Color(red: 0.24, green: 0.15, blue: 0.10))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.97, green: 0.93, blue: 0.82))
                        .overlay(RoundedRectangle(cornerRadius: 4).inset(by: 2).stroke(Color(red: 0.35, green: 0.23, blue: 0.15), lineWidth: 4))
                )
                .overlay(alignment: .bottomTrailing) {
                    if options.isEmpty {
                        Text("▼")
                            .font(.pixel(12))
                            .foregroundStyle(Color(red: 0.35, green: 0.23, blue: 0.15))
                            .padding(10)
                    }
                }

                if !options.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("【　】に入る言葉は？")
                            .font(.pixel(13))
                            .foregroundStyle(Color(white: 0.8))
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            Button {
                                proceed(index)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrowtriangle.right.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ShelfPalette.highlight)
                                    Text(option)
                                        .font(.pixel(17))
                                        .foregroundStyle(.white)
                                }
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(RetroWindowBackground())
                }
            }
            .padding(.horizontal, 20)
            .opacity(isShown ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if options.isEmpty { proceed(0) }
        }
        .task {
            withAnimation(.easeOut(duration: 0.35)) { isShown = true }
        }
    }

    /// 虫食いの【　】だけ色を変えて目立たせる
    private var highlightedText: Text {
        var result = Text("")
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "【"), let close = rest[open...].firstIndex(of: "】") {
            result = Text("\(result)\(Text(String(rest[..<open])))\(Text(String(rest[open...close])).foregroundStyle(Color(red: 0.75, green: 0.25, blue: 0.20)))")
            rest = rest[rest.index(after: close)...]
        }
        return Text("\(result)\(Text(String(rest)))")
    }
}

/// 「◯◯を てにいれた！」
private struct ItemGetView: View {
    let item: StoryItem
    let proceed: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(item.imageName)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("\(item.name) を てにいれた！")
                    .font(.pixel(18))
                    .foregroundStyle(ShelfPalette.highlight)
                Text(item.detail)
                    .font(.pixel(14))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(RetroWindowBackground())
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: proceed)
    }
}
