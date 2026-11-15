import SwiftUI

/// 作品の詳細とダウンロード
struct BookDetailView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ErrandStore.self) private var errands
    @Environment(StoryStore.self) private var story
    let book: CatalogBook

    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false
    @State private var borrowNote: String?

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

            if let task = StoryDayTask.borrowing(book, story: story) {
                Section {
                    Button("夜の図書室へ持っていく（かりる）", systemImage: "moon.stars") {
                        task.borrow(into: story)
                        borrowNote = task.borrowNote
                    }
                }
            } else if let borrowNote, errands.carrying?.id != book.id {
                Section {
                    Text(borrowNote)
                }
            }

            if errands.isLookingForBook {
                Section {
                    if errands.carrying?.id == book.id {
                        Label("町の人に届けるために、かりています", systemImage: "bag")
                    } else {
                        Button("町の人に届ける（かりる）", systemImage: "bag.badge.plus") {
                            errands.borrow(book)
                            borrowNote = errands.borrowNote(for: book)
                        }
                    }
                } footer: {
                    if let borrowNote {
                        Text(borrowNote)
                    }
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
