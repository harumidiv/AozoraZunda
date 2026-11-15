//
//  ContentView.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import SwiftUI

/// ずんだもんの部屋・町・図書館。タブはなく、部屋のドアから町に出て、町から図書館に入る。
/// 部屋のベッドで夜まで待つと、ストーリーの舞台の夜間図書室へ行ける
struct ContentView: View {
    @Environment(StoryStore.self) private var story

    private enum Place: Equatable {
        case room
        /// entrance: どこから町に出てきたか
        case town(entrance: TownScene.Entrance)
        case library
        case nightLibrary
    }

    @State private var place = Place.room
    /// 町から帰ってきたときは、部屋のドアの前から始める
    @State private var cameHomeFromOutside = false

    var body: some View {
        ZStack {
            switch place {
            case .room:
                LibraryView(
                    startsAtDoor: cameHomeFromOutside,
                    goOutside: { go(to: .town(entrance: .home)) },
                    goToLibrary: { go(to: .library) },
                    goToNightLibrary: { go(to: .nightLibrary, duration: 1.0) }
                )
                .transition(.opacity)
            case .town(let entrance):
                TownView(
                    entrance: entrance,
                    goHome: { go(to: .room) },
                    goToLibrary: { go(to: .library) }
                )
                .id(entrance)
                .transition(.opacity)
            case .library:
                CatalogView { go(to: .town(entrance: .library)) }
                    .transition(.opacity)
            case .nightLibrary:
                NightLibraryView(story: story) { go(to: .room, duration: 1.0, fromLibrary: false) }
                    .transition(.opacity)
            }
        }
        .onChange(of: place, initial: true) { _, place in
            // 夜間図書室の曲は、本の中かどうかで変わるので NightLibraryView が決める
            switch place {
            case .room: MusicPlayer.shared.play(.room)
            case .town: MusicPlayer.shared.play(.town)
            case .library: MusicPlayer.shared.play(nil)
            case .nightLibrary: break
            }
        }
    }

    /// fromLibrary: 部屋に帰るとき、ドアの前から始めるか（夜間図書室から帰ったときは、朝になってベッドのそばから）
    private func go(to destination: Place, duration: TimeInterval = 0.35, fromLibrary: Bool = true) {
        withAnimation(.easeInOut(duration: duration)) {
            cameHomeFromOutside = destination == .room && fromLibrary
            place = destination
        }
    }
}

#Preview {
    ContentView()
        .environment(CatalogStore())
        .environment(LibraryStore())
        .environment(StoryStore())
        .environment(ErrandStore())
}
