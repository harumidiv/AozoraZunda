//
//  ContentView.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import SwiftUI

/// ずんだもんの部屋と図書館。タブはなく、部屋のドアと図書館の入口を歩いて行き来する。
/// 部屋のベッドで夜まで待つと、ストーリーの舞台の夜間図書室へ行ける
struct ContentView: View {
    @Environment(StoryStore.self) private var story

    private enum Place {
        case room, library, nightLibrary
    }

    @State private var place = Place.room
    /// 図書館から帰ってきたときは、部屋のドアの前から始める
    @State private var cameHomeFromLibrary = false

    var body: some View {
        ZStack {
            switch place {
            case .room:
                LibraryView(
                    startsAtDoor: cameHomeFromLibrary,
                    goToLibrary: { go(to: .library) },
                    goToNightLibrary: { go(to: .nightLibrary, duration: 1.0) }
                )
                .transition(.opacity)
            case .library:
                CatalogView { go(to: .room) }
                    .transition(.opacity)
            case .nightLibrary:
                NightLibraryView(story: story) { go(to: .room, duration: 1.0, fromLibrary: false) }
                    .transition(.opacity)
            }
        }
    }

    /// fromLibrary: 部屋に帰るとき、ドアの前から始めるか（夜間図書室から帰ったときは、朝になってベッドのそばから）
    private func go(to destination: Place, duration: TimeInterval = 0.35, fromLibrary: Bool = true) {
        withAnimation(.easeInOut(duration: duration)) {
            cameHomeFromLibrary = destination == .room && fromLibrary
            place = destination
        }
    }
}

#Preview {
    ContentView()
        .environment(CatalogStore())
        .environment(LibraryStore())
        .environment(StoryStore())
}
