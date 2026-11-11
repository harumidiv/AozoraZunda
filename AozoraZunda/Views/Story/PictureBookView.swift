import AVFoundation
import Observation
import SwiftUI

/// 絵本を1ページずつめくって読み聞かせる画面。ずんだもんの声（VOICEVOX）で読み上げる
struct PictureBookView: View {
    let book: PictureBook
    let close: () -> Void

    @State private var page = 0
    @State private var voice = PageVoice()
    @AppStorage("story.pictureBookVoice") private var isVoiceOn = true

    private var isLastPage: Bool { page == book.pages.count - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("『\(book.title)』")
                    .font(.pixel(15))
                    .foregroundStyle(Color(white: 0.8))

                pageView
                    .id(page)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

                HStack {
                    Button { turn(to: page - 1) } label: {
                        Label("まえ", systemImage: "arrowtriangle.left.fill")
                            .labelStyle(PageArrowLabelStyle(trailing: false))
                    }
                        .opacity(page > 0 ? 1 : 0)
                        .disabled(page == 0)
                    Spacer()
                    Text("\(page + 1) / \(book.pages.count)")
                        .foregroundStyle(Color(white: 0.7))
                    Spacer()
                    Button {
                        if isLastPage {
                            voice.stop()
                            close()
                        } else {
                            turn(to: page + 1)
                        }
                    } label: {
                        if isLastPage {
                            Text("とじる")
                        } else {
                            Label("つぎ", systemImage: "arrowtriangle.right.fill")
                                .labelStyle(PageArrowLabelStyle(trailing: true))
                        }
                    }
                }
                .font(.pixel(17))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button {
                    isVoiceOn.toggle()
                    if isVoiceOn {
                        readCurrentPage()
                    } else {
                        voice.stop()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isVoiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(isVoiceOn ? "ずんだもんが こえに だして よむ" : "こえは おやすみ中")
                        if voice.isLoading {
                            ProgressView().tint(.white).controlSize(.small)
                        }
                    }
                    .font(.pixel(13))
                    .foregroundStyle(Color(white: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            // 読み上げの声が聞こえるよう、曲は小さくしておく
            MusicPlayer.shared.setDucked(true)
            readCurrentPage()
        }
        .onDisappear {
            voice.stop()
            MusicPlayer.shared.setDucked(false)
        }
    }

    private var pageView: some View {
        let current = book.pages[page]
        return VStack(spacing: 14) {
            if let imageName = current.imageName {
                Image(imageName)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
            }
            Text(current.text)
                .font(.pixel(18))
                .lineSpacing(8)
                .foregroundStyle(Color(red: 0.24, green: 0.15, blue: 0.10))
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.97, green: 0.93, blue: 0.82))
                .overlay(RoundedRectangle(cornerRadius: 4).inset(by: 2).stroke(Color(red: 0.35, green: 0.23, blue: 0.15), lineWidth: 4))
        )
    }

    private func turn(to newPage: Int) {
        guard book.pages.indices.contains(newPage) else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            page = newPage
        }
        readCurrentPage()
    }

    private func readCurrentPage() {
        guard isVoiceOn else { return }
        voice.read(book.pages[page].text, next: book.pages.indices.contains(page + 1) ? book.pages[page + 1].text : nil)
    }
}

/// 「◀ まえ」「つぎ ▶」の矢印。ドット文字のフォントには矢印がないので記号の画像を小さく添える
private struct PageArrowLabelStyle: LabelStyle {
    let trailing: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if !trailing { configuration.icon.font(.system(size: 11)) }
            configuration.title
            if trailing { configuration.icon.font(.system(size: 11)) }
        }
    }
}

/// ページの文章をずんだもんの声で読む。次のページの分も先に作っておき、めくってすぐ読めるようにする
@Observable
private final class PageVoice {
    private(set) var isLoading = false
    private var player: AVAudioPlayer?
    private var synthesized: [String: Task<Data, Error>] = [:]
    private var reading: Task<Void, Never>?

    func read(_ text: String, next: String?) {
        stop()
        reading = Task {
            isLoading = true
            let data = try? await synthesize(text).value
            isLoading = false
            guard !Task.isCancelled, let data else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)
            player = try? AVAudioPlayer(data: data)
            player?.play()
            if let next {
                _ = synthesize(next)
            }
        }
    }

    func stop() {
        reading?.cancel()
        reading = nil
        player?.stop()
        player = nil
        isLoading = false
    }

    private func synthesize(_ text: String) -> Task<Data, Error> {
        if let task = synthesized[text] { return task }
        let task = Task { try await ZundaVoiceEngine.shared.synthesize(text, style: .amaama) }
        synthesized[text] = task
        return task
    }
}
