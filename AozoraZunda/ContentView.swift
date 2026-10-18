//
//  ContentView.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import SwiftUI

/// ずんだもんの部屋と図書館。タブはなく、部屋のドアと図書館の入口を歩いて行き来する
struct ContentView: View {
    private enum Place {
        case room, library
    }

    @State private var place = Place.room
    /// 図書館から帰ってきたときは、部屋のドアの前から始める
    @State private var cameHomeFromLibrary = false

    var body: some View {
        ZStack {
            switch place {
            case .room:
                LibraryView(startsAtDoor: cameHomeFromLibrary) { go(to: .library) }
                    .transition(.opacity)
            case .library:
                CatalogView { go(to: .room) }
                    .transition(.opacity)
            }
        }
    }

    private func go(to destination: Place) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameHomeFromLibrary = destination == .room
            place = destination
        }
    }
}

#Preview {
    ContentView()
        .environment(CatalogStore())
        .environment(LibraryStore())
}
