import SwiftUI

/// 作品の詳細とダウンロード
struct BookDetailView: View {
    @Environment(LibraryStore.self) private var library
    let book: CatalogBook

    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.title2.bold())
                    if !book.subtitle.isEmpty {
                        Text(book.subtitle)
                            .font(.headline)
                    }
                    Text(book.titleYomi)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("著者", value: book.authorName)
                if !book.translatorName.isEmpty {
                    LabeledContent("翻訳", value: book.translatorName)
                }
                if !book.kanaType.isEmpty {
                    LabeledContent("文字遣い", value: book.kanaType)
                }
                if !book.firstAppearance.isEmpty {
                    LabeledContent("初出", value: book.firstAppearance)
                }
                Link(destination: book.cardURL) {
                    Label("図書カードを開く", systemImage: "safari")
                }
            }

            Section {
                actionButton
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("本棚から削除しますか？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                library.delete(book.id)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if library.isDownloaded(book.id) {
            NavigationLink(value: ReaderRoute(book: book)) {
                Label("読む", systemImage: "book")
            }
            Button("本棚から削除", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        } else if library.isDownloading(book.id) {
            HStack {
                ProgressView()
                Text("ダウンロード中…")
                    .padding(.leading, 8)
            }
        } else {
            Button("ダウンロードして本棚に追加", systemImage: "arrow.down.circle") {
                Task {
                    errorMessage = nil
                    do {
                        try await library.download(book)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
