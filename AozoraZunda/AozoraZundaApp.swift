//
//  AozoraZundaApp.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import GoogleMobileAds
import SwiftUI

@main
struct AozoraZundaApp: App {
    @State private var catalogStore = CatalogStore()
    @State private var libraryStore = LibraryStore()

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(catalogStore)
                .environment(libraryStore)
        }
    }
}
