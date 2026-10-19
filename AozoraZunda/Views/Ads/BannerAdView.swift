import GoogleMobileAds
import SwiftUI

enum AdConfig {
    /// 開発中は Google のテスト用広告を出す（自分の本番広告を表示・タップすると無効なトラフィックになるため）
    static var bannerUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2435281174"
        #else
        "ca-app-pub-8522231452310619/4997537112"
        #endif
    }
}

/// 画面幅に合わせたアダプティブバナー
struct BannerAdView: View {
    @State private var width: CGFloat = 320

    var body: some View {
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        // 幅は空のビューで測る（広告ビュー自身の大きさが測った幅に影響しないように）
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: adSize.size.height)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 320) }
            .overlay {
                BannerViewContainer(adSize: adSize)
                    .frame(width: adSize.size.width, height: adSize.size.height)
            }
            .accessibilityLabel("広告")
    }
}

/// 広告ビューは枠の大きさが変わると勝手に読み込み直して大きさも変えてしまうので、
/// 1枚 UIView で包んで SwiftUI の大きさ調整が直接届かないようにする（Google の SwiftUI サンプルと同じ形）
private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize

    func makeCoordinator() -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.load(Request())
        return banner
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        context.coordinator.frame = CGRect(origin: .zero, size: adSize.size)
        container.addSubview(context.coordinator)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        let banner = context.coordinator
        // 画面の回転などで幅が変わったら、その幅の広告を読み込み直す
        guard !CGSizeEqualToSize(banner.adSize.size, adSize.size) else { return }
        banner.adSize = adSize
        banner.frame = CGRect(origin: .zero, size: adSize.size)
        banner.load(Request())
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        adSize.size
    }
}
