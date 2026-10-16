//
//  ContentView.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("本棚", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("さがす", systemImage: "magnifyingglass", role: .search) {
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
