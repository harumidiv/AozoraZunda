import GoogleMobileAds
import SwiftUI
import UIKit

extension AdConfig {
    /// 本棚の途中に入れるネイティブ広告（開発中は Google のテスト用広告）
    static var shelfNativeUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/3986624511"
        #else
        "ca-app-pub-8522231452310619/7487969089"
        #endif
    }
}

/// 本棚の途中に入れる「広告の段」。棚の枠と棚板は本棚に合わせ、中身は本と見分けがつくカードにする。
/// 画面に近づいたときに読み込み、読み込めなかったら何も出さない
struct NativeAdShelfRow: View {
    @State private var slot = NativeAdSlot()

    var body: some View {
        Group {
            if let ad = slot.ad {
                VStack(spacing: 0) {
                    NativeAdCard(nativeAd: ad)
                        .frame(height: NativeAdCard.height)
                        // 本をタップするつもりで広告を押さないよう、上下に余白を取る
                        .padding(.horizontal, ShelfLayout.rowInset)
                        .padding(.vertical, 14)
                        .background(ShelfPalette.back)
                    Rectangle()
                        .fill(ShelfPalette.plank)
                        .frame(height: 14)
                        .overlay(alignment: .top) {
                            Rectangle().fill(ShelfPalette.plankLight).frame(height: 3)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(ShelfPalette.outline).frame(height: 3)
                        }
                }
                .padding(.horizontal, 4)
                .background(ShelfPalette.frame)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .onAppear { slot.loadIfNeeded() }
    }
}

/// 広告の段1つ分のネイティブ広告を読み込む
@Observable
final class NativeAdSlot: NSObject, NativeAdLoaderDelegate {
    private(set) var ad: NativeAd?
    @ObservationIgnored private var loader: AdLoader?

    func loadIfNeeded() {
        guard loader == nil else { return }
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        let loader = AdLoader(adUnitID: AdConfig.shelfNativeUnitID, rootViewController: root, adTypes: [.native], options: nil)
        loader.delegate = self
        self.loader = loader
        loader.load(Request())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        ad = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        // 読み込めなかった段は何も表示しない
    }
}

/// ネイティブ広告のカード。左に画像・動画、右に「広告」の札・見出し・本文・ボタン
private struct NativeAdCard: UIViewRepresentable {
    let nativeAd: NativeAd

    /// 画像・動画の枠はポリシー上 120x120 以上にする
    static let mediaSize: CGFloat = 120
    static let height: CGFloat = mediaSize + 16

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.backgroundColor = UIColor(red: 0.97, green: 0.94, blue: 0.86, alpha: 1)
        adView.layer.cornerRadius = 8
        adView.layer.borderWidth = 2
        adView.layer.borderColor = UIColor(ShelfPalette.outline).cgColor
        adView.clipsToBounds = true

        let media = MediaView()
        let badge = PaddedLabel()
        badge.text = "広告"
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(red: 0.24, green: 0.14, blue: 0.08, alpha: 1)
        badge.backgroundColor = UIColor(ShelfPalette.highlight)
        badge.layer.cornerRadius = 3
        badge.clipsToBounds = true

        let headline = UILabel()
        headline.font = .systemFont(ofSize: 15, weight: .bold)
        headline.textColor = .black
        headline.numberOfLines = 2

        let body = UILabel()
        body.font = .systemFont(ofSize: 12)
        body.textColor = .darkGray
        body.numberOfLines = 2

        let callToAction = PaddedLabel()
        callToAction.font = .systemFont(ofSize: 13, weight: .bold)
        callToAction.textColor = .white
        callToAction.backgroundColor = UIColor(red: 0.35, green: 0.66, blue: 0.24, alpha: 1)
        callToAction.layer.cornerRadius = 6
        callToAction.clipsToBounds = true
        // タップは広告ビュー全体で SDK が受け取る
        callToAction.isUserInteractionEnabled = false

        let text = UIStackView(arrangedSubviews: [badge, headline, body, callToAction])
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = 4
        text.setCustomSpacing(8, after: body)

        for view in [media, text] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            media.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
            media.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            media.widthAnchor.constraint(equalToConstant: Self.mediaSize),
            media.heightAnchor.constraint(equalToConstant: Self.mediaSize),
            text.leadingAnchor.constraint(equalTo: media.trailingAnchor, constant: 10),
            // 右上は SDK が AdChoices のアイコンを置くので空けておく
            text.trailingAnchor.constraint(lessThanOrEqualTo: adView.trailingAnchor, constant: -26),
            text.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: adView.topAnchor, constant: 8),
        ])

        adView.mediaView = media
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = callToAction
        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        guard adView.nativeAd !== nativeAd else { return }
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil
        (adView.callToActionView as? UILabel)?.text = nativeAd.callToAction
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        // 素材を入れ終わってから広告を渡す（表示回数とクリックの計測が始まる）
        adView.nativeAd = nativeAd
    }
}

/// 内側に余白のあるラベル（「広告」の札とボタン用）
private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
