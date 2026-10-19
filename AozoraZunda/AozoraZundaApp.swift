//
//  AozoraZundaApp.swift
//  AozoraZunda
//
//  Created by harumi.sagawa on 2026/10/16.
//

import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI

@main
struct AozoraZundaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var catalogStore = CatalogStore()
    @State private var libraryStore = LibraryStore()
    @State private var hasStartedAds = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(catalogStore)
                .environment(libraryStore)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            Task { await requestTrackingThenStartAds() }
        }
    }

    /// ATT ダイアログはアプリがアクティブなときにしか出せないので、active になってから要求する。
    /// 選択結果を広告リクエストに反映させるため、広告 SDK の初期化はその後に行う
    @MainActor
    private func requestTrackingThenStartAds() async {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard !hasStartedAds else { return }
        hasStartedAds = true
        MobileAds.shared.start(completionHandler: nil)
    }
}
