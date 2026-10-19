import GoogleMobileAds
import Observation
import UIKit

extension AdConfig {
    /// 部屋のテレビで流す動画のインタースティシャル広告。本番の広告ユニットがまだないときは nil（テレビには何も映らない）
    static var tvInterstitialUnitID: String? {
        #if DEBUG
        "ca-app-pub-3940256099942544/5135589807"
        #else
        nil
        #endif
    }
}

/// 部屋のテレビを調べて「みる」を選んだときに流す全画面広告。先に読み込んでおき、見終わったら次を読み込む
@Observable
final class TVAdController: NSObject, FullScreenContentDelegate {
    private(set) var isReady = false
    /// 広告を閉じたときに呼ばれる
    @ObservationIgnored var onDismiss: (() -> Void)?

    @ObservationIgnored private var ad: InterstitialAd?
    @ObservationIgnored private var isLoading = false

    func load() {
        guard ad == nil, !isLoading, let unitID = AdConfig.tvInterstitialUnitID else { return }
        isLoading = true
        InterstitialAd.load(with: unitID, request: Request()) { [weak self] ad, _ in
            // 読み込み完了はメインスレッドで呼ばれる
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isLoading = false
                self.ad = ad
                ad?.fullScreenContentDelegate = self
                self.isReady = ad != nil
            }
        }
    }

    /// 広告を流す。読み込めていなければ false
    func present() -> Bool {
        guard let ad, let root = Self.topViewController() else { return false }
        ad.present(from: root)
        return true
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        reset()
        onDismiss?()
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        reset()
    }

    private func reset() {
        ad = nil
        isReady = false
        load()
    }

    private static func topViewController() -> UIViewController? {
        var controller = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
