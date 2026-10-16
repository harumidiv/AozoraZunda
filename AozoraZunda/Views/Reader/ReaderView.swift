import SwiftUI

/// ダウンロード済み作品の読書画面
struct ReaderView: View {
    @Environment(LibraryStore.self) private var library
    let book: CatalogBook

    @AppStorage("reader.isVertical") private var isVertical = true
    @AppStorage("reader.fontSize") private var fontSize = 18.0
    @AppStorage("reader.theme") private var theme = ReaderTheme.white
    @AppStorage("reader.zundaStyle") private var zundaStyle = ZundaStyle.normal

    @State private var document: AozoraDocument?
    @State private var initialProgress = 0.0
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var isChromeHidden = false
    @State private var readAloud = ReadAloudController()

    private var appearance: ReaderAppearance {
        ReaderAppearance(isVertical: isVertical, fontSize: fontSize, theme: theme)
    }

    var body: some View {
        ZStack {
            theme.color.ignoresSafeArea()
            if let document {
                PagedBookView(
                    document: document,
                    book: book,
                    appearance: appearance,
                    initialProgress: initialProgress,
                    onProgress: { progress in
                        library.updateProgress(book.id, progress: progress)
                    },
                    onPageTurn: {
                        // 読み上げ中に手でページをめくったら、そのページから読み直す
                        readAloud.restart()
                        guard !isChromeHidden, !isShowingSettings else { return }
                        withAnimation { isChromeHidden = true }
                    },
                    onToggleChrome: {
                        withAnimation { isChromeHidden.toggle() }
                    },
                    readAloud: readAloud
                )
                .ignoresSafeArea()
            } else if let errorMessage {
                ContentUnavailableView("作品を開けませんでした", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ProgressView()
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarVisibility(isChromeHidden ? .hidden : .visible, for: .navigationBar)
        .toolbarColorScheme(theme == .dark ? .dark : .light, for: .navigationBar)
        .overlay(alignment: .bottomLeading) {
            // 本文の下の余白（ページ番号より左）に収まるように置く
            ReadAloudBar(readAloud: readAloud, theme: theme)
                .padding(.leading, 16)
                .padding(.bottom, 4)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    readAloud.isActive ? "読み上げを止める" : "ずんだもんが読み上げる",
                    systemImage: readAloud.isActive ? "stop.fill" : "speaker.wave.2.fill"
                ) {
                    if readAloud.isActive {
                        readAloud.stop()
                    } else {
                        readAloud.start(style: zundaStyle)
                    }
                }
                .disabled(document == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("表示設定", systemImage: "textformat.size") {
                    isShowingSettings = true
                }
                .popover(isPresented: $isShowingSettings) {
                    ReaderSettingsView(isVertical: $isVertical, fontSize: $fontSize, theme: $theme, zundaStyle: $zundaStyle)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .onChange(of: zundaStyle) { _, style in
            readAloud.restart(style: style)
        }
        .onChange(of: appearance) {
            // 組版し直すとページが変わるので、読み上げは止める
            readAloud.stop()
        }
        .onDisappear {
            readAloud.stop()
        }
        .task {
            await loadDocument()
        }
    }

    private func loadDocument() async {
        guard document == nil else { return }
        do {
            let text = try await library.loadText(for: book.id)
            initialProgress = library.libraryBook(for: book.id)?.progress ?? 0
            document = await Self.parse(text)
            library.markOpened(book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @concurrent
    private static func parse(_ text: String) async -> AozoraDocument {
        AozoraTextParser.parse(text)
    }
}

private struct ReaderSettingsView: View {
    @Binding var isVertical: Bool
    @Binding var fontSize: Double
    @Binding var theme: ReaderTheme
    @Binding var zundaStyle: ZundaStyle

    /// スライダーを動かしている間に毎回組版し直さないよう、離したときに反映する
    @State private var draftFontSize: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("組み方向", selection: $isVertical) {
                Text("縦書き").tag(true)
                Text("横書き").tag(false)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("文字の大きさ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "textformat.size.smaller")
                    Slider(
                        value: Binding(get: { draftFontSize ?? fontSize }, set: { draftFontSize = $0 }),
                        in: 12...32,
                        step: 1
                    ) { isEditing in
                        if !isEditing, let draftFontSize {
                            fontSize = draftFontSize
                            self.draftFontSize = nil
                        }
                    }
                    Image(systemName: "textformat.size.larger")
                }
            }

            Picker("テーマ", selection: $theme) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("読み上げの声")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("読み上げの声", selection: $zundaStyle) {
                        ForEach(ZundaStyle.allCases) { style in
                            Text("ずんだもん（\(style.label)）").tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Text("VOICEVOX:ずんだもん")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

/// 読み上げ中に左下の余白に出す、誰がどの声で読んでいるかの札。タップすると止める
private struct ReadAloudBar: View {
    let readAloud: ReadAloudController
    let theme: ReaderTheme

    var body: some View {
        if let message {
            Button {
                readAloud.stop()
            } label: {
                HStack(spacing: 8) {
                    if readAloud.state == .preparing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: isFailed ? "exclamationmark.triangle.fill" : "speaker.wave.2.fill")
                            .symbolEffect(.variableColor.iterative, isActive: readAloud.state == .speaking)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(message)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(2)
                        Text("VOICEVOX:ずんだもん")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .environment(\.colorScheme, theme == .dark ? .dark : .light)
            .accessibilityHint(readAloud.isActive ? "タップすると読み上げを止めます" : "")
            .transition(.opacity)
        }
    }

    private var isFailed: Bool {
        if case .failed = readAloud.state { true } else { false }
    }

    private var message: String? {
        switch readAloud.state {
        case .idle: nil
        case .preparing: "読む準備中なのだ…"
        case .speaking: "ずんだもん（\(readAloud.style.label)）"
        case .failed(let reason): "読み上げられなかったのだ…（\(reason)）"
        }
    }
}

extension ReaderTheme {
    var color: Color {
        Color(cgColor: background)
    }
}
