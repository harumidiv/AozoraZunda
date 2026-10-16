import SwiftUI

/// ダウンロード済み作品の読書画面
struct ReaderView: View {
    @Environment(LibraryStore.self) private var library
    let book: CatalogBook

    @AppStorage("reader.isVertical") private var isVertical = true
    @AppStorage("reader.fontSize") private var fontSize = 18.0
    @AppStorage("reader.theme") private var theme = ReaderTheme.white

    @State private var document: AozoraDocument?
    @State private var initialProgress = 0.0
    @State private var errorMessage: String?
    @State private var isShowingSettings = false
    @State private var isChromeHidden = false

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
                        guard !isChromeHidden, !isShowingSettings else { return }
                        withAnimation { isChromeHidden = true }
                    },
                    onToggleChrome: {
                        withAnimation { isChromeHidden.toggle() }
                    }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("表示設定", systemImage: "textformat.size") {
                    isShowingSettings = true
                }
                .popover(isPresented: $isShowingSettings) {
                    ReaderSettingsView(isVertical: $isVertical, fontSize: $fontSize, theme: $theme)
                        .presentationCompactAdaptation(.popover)
                }
            }
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
        }
        .padding()
        .frame(width: 300)
    }
}

extension ReaderTheme {
    var color: Color {
        Color(cgColor: background)
    }
}
