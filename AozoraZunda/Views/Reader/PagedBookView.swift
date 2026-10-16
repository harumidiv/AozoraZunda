import SwiftUI
import UIKit

/// 本物の本のようにページをめくって読むビュー（UIPageViewController の pageCurl）
struct PagedBookView: UIViewControllerRepresentable {
    let document: AozoraDocument
    let book: CatalogBook
    let appearance: ReaderAppearance
    let initialProgress: Double
    let onProgress: (Double) -> Void
    let onPageTurn: () -> Void
    let onToggleChrome: () -> Void

    func makeUIViewController(context: Context) -> PagedBookViewController {
        PagedBookViewController(
            document: document,
            title: book.displayTitle,
            credit: book.displayCredit,
            appearance: appearance,
            initialProgress: initialProgress
        )
    }

    func updateUIViewController(_ controller: PagedBookViewController, context: Context) {
        controller.onProgress = onProgress
        controller.onPageTurn = onPageTurn
        controller.onToggleChrome = onToggleChrome
        controller.update(appearance: appearance)
    }
}

final class PagedBookViewController: UIViewController {
    var onProgress: ((Double) -> Void)?
    var onPageTurn: (() -> Void)?
    var onToggleChrome: (() -> Void)?

    private let document: AozoraDocument
    private let bookTitle: String
    private let credit: String
    private var appearance: ReaderAppearance

    private var book: PaginatedBook?
    private var currentPage = 0
    /// 再組版の前後で同じ箇所を開くための文字位置
    private var anchorLocation: Int?
    private var initialProgress: Double?
    private var paginatedKey: PaginationKey?
    private var paginationTask: Task<Void, Never>?
    /// 現在の組版設定でページを表示し始めたか
    private var hasInstalledCurrentPagination = false

    private var pageController: UIPageViewController?
    private let spinner = UIActivityIndicatorView(style: .large)
    private let centerTap = UITapGestureRecognizer()

    private struct PaginationKey: Equatable {
        let layout: PageLayout
        let appearance: ReaderAppearance
    }

    init(document: AozoraDocument, title: String, credit: String, appearance: ReaderAppearance, initialProgress: Double) {
        self.document = document
        self.bookTitle = title
        self.credit = credit
        self.appearance = appearance
        self.initialProgress = initialProgress
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(cgColor: appearance.theme.background)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // 画面中央のタップでメニューの表示を切り替える（左右の端はページめくり）
        centerTap.addTarget(self, action: #selector(handleCenterTap))
        centerTap.delegate = self
        view.addGestureRecognizer(centerTap)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 縦書きでは左端からページをめくるので、戻るスワイプと競合させない
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        repaginateIfNeeded()
    }

    func update(appearance: ReaderAppearance) {
        guard appearance != self.appearance else { return }
        self.appearance = appearance
        view.backgroundColor = UIColor(cgColor: appearance.theme.background)
        repaginateIfNeeded()
    }

    // MARK: - Pagination

    private func makeLayout() -> PageLayout? {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        // ナビゲーションバーの表示切り替えで組版が変わらないよう、ウインドウの安全領域だけを使う
        let safeArea = view.window?.safeAreaInsets ?? view.safeAreaInsets
        let top = safeArea.top + 20
        let bottom = max(safeArea.bottom, 12) + 36
        let left = safeArea.left + 26
        let right = safeArea.right + 26
        return PageLayout(
            pageSize: size,
            textRect: CGRect(x: left, y: top, width: size.width - left - right, height: size.height - top - bottom),
            isVertical: appearance.isVertical
        )
    }

    private func repaginateIfNeeded() {
        guard let layout = makeLayout() else { return }
        let key = PaginationKey(layout: layout, appearance: appearance)
        guard key != paginatedKey else { return }
        paginatedKey = key

        if let book {
            anchorLocation = book.pages[currentPage].location
        }
        paginationTask?.cancel()
        hasInstalledCurrentPagination = false
        spinner.color = UIColor(cgColor: appearance.theme.subtle)
        spinner.startAnimating()

        let stream = Self.paginationStream(document: document, title: bookTitle, credit: credit, appearance: appearance, layout: layout)
        paginationTask = Task { [weak self] in
            for await book in stream {
                guard !Task.isCancelled, let self else { return }
                self.receive(book)
            }
        }
    }

    /// 組版をバックグラウンドで行い、途中経過と最終結果を流す
    nonisolated private static func paginationStream(
        document: AozoraDocument,
        title: String,
        credit: String,
        appearance: ReaderAppearance,
        layout: PageLayout
    ) -> AsyncStream<PaginatedBook> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let sections = AozoraAttributedRenderer.render(document, title: title, credit: credit, appearance: appearance)
                let book = BookPaginator.paginate(sections, layout: layout) { continuation.yield($0) }
                if let book { continuation.yield(book) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func receive(_ book: PaginatedBook) {
        guard hasInstalledCurrentPagination else {
            install(book)
            return
        }
        // 表示中は分割済みのページを増やしていくだけ。完了したら総ページ数を表示し直す
        self.book = book
        if book.isComplete {
            pageController?.setViewControllers([makePage(currentPage)], direction: .forward, animated: false)
        }
    }

    private func install(_ book: PaginatedBook) {
        let targetLocation: Int? = if let anchorLocation {
            anchorLocation
        } else if let initialProgress {
            Int(initialProgress * Double(book.totalLength))
        } else {
            nil
        }
        // 開きたい位置のページがまだ分割されていなければ続きを待つ
        if let targetLocation, !book.isComplete, let last = book.pages.last, last.location <= targetLocation {
            return
        }

        let isVerticalChanged = self.book?.layout.isVertical != book.layout.isVertical
        self.book = book
        currentPage = targetLocation.map { book.pageIndex(containing: $0) } ?? 0
        initialProgress = nil
        hasInstalledCurrentPagination = true

        if pageController == nil || isVerticalChanged {
            installPageController(isVertical: book.layout.isVertical)
        }
        pageController?.setViewControllers([makePage(currentPage)], direction: .forward, animated: false)
        spinner.stopAnimating()
    }

    private func installPageController(isVertical: Bool) {
        if let old = pageController {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        // 縦書きは右綴じ（背が右）、横書きは左綴じ（背が左）
        let spine: UIPageViewController.SpineLocation = isVertical ? .max : .min
        let controller = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: spine.rawValue)]
        )
        controller.isDoubleSided = false
        controller.dataSource = self
        controller.delegate = self

        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(controller.view, belowSubview: spinner)
        controller.didMove(toParent: self)

        // 中央タップが優先され、端のタップだけがページめくりになるようにする
        for recognizer in controller.gestureRecognizers where recognizer is UITapGestureRecognizer {
            recognizer.require(toFail: centerTap)
        }
        pageController = controller
    }

    private func makePage(_ index: Int) -> BookPageViewController {
        BookPageViewController(book: book!, index: index, theme: appearance.theme)
    }

    @objc private func handleCenterTap() {
        onToggleChrome?()
    }
}

extension PagedBookViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    // 右綴じ（背が右）の UIPageViewController は左端をめくる操作を「前のページ」として扱うので、
    // 縦書きでは前後を入れ替えて、左端をめくると次のページに進むようにする
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        page(from: viewController, offset: book?.layout.isVertical == true ? 1 : -1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        page(from: viewController, offset: book?.layout.isVertical == true ? -1 : 1)
    }

    private func page(from viewController: UIViewController, offset: Int) -> UIViewController? {
        guard let book, let page = viewController as? BookPageViewController else { return nil }
        let index = page.index + offset
        guard book.pages.indices.contains(index) else { return nil }
        return makePage(index)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed, let book, let page = pageViewController.viewControllers?.first as? BookPageViewController else { return }
        currentPage = page.index
        anchorLocation = nil
        onProgress?(book.progress(atPage: page.index))
        onPageTurn?()
    }
}

extension PagedBookViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === centerTap else { return true }
        let x = touch.location(in: view).x
        let width = view.bounds.width
        return x > width * 0.3 && x < width * 0.7
    }
}

/// 1ページ分
final class BookPageViewController: UIViewController {
    let index: Int
    private let book: PaginatedBook
    private let theme: ReaderTheme

    init(book: PaginatedBook, index: Int, theme: ReaderTheme) {
        self.book = book
        self.index = index
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BookPageView(book: book, index: index, theme: theme)
    }
}

private final class BookPageView: UIView {
    private let book: PaginatedBook
    private let index: Int
    private let theme: ReaderTheme

    init(book: PaginatedBook, index: Int, theme: ReaderTheme) {
        self.book = book
        self.index = index
        self.theme = theme
        super.init(frame: CGRect(origin: .zero, size: book.layout.pageSize))
        isOpaque = true
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(theme.background)
        context.fill(bounds)

        // CoreText は左下原点なので上下を反転して描く
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        BookPaginator.draw(book, page: index, in: context)
        context.restoreGState()

        drawPageNumber()
    }

    private func drawPageNumber() {
        let text = (book.isComplete ? "\(index + 1) / \(book.pages.count)" : "\(index + 1)") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(cgColor: theme.subtle),
        ]
        let size = text.size(withAttributes: attributes)
        let bottomInset = book.layout.pageSize.height - book.layout.textRect.maxY
        let origin = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - bottomInset + (bottomInset - size.height) / 2 - 6
        )
        text.draw(at: origin, withAttributes: attributes)
    }
}
