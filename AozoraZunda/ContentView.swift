//
//  ContentView.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import SwiftUI

struct ContentView: View {
    private enum AppTab {
        case room, library
    }

    @State private var tab = AppTab.room

    var body: some View {
        TabView(selection: $tab) {
            Tab("本棚", systemImage: "books.vertical", value: .room) {
                // 部屋のドアから図書館へ出かけられる
                LibraryView { tab = .library }
            }
            Tab("としょかん", systemImage: "building.columns", value: .library) {
                CatalogView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(CatalogStore())
        .environment(LibraryStore())
}
