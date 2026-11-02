import UIKit
import FSPagerView

// Public API surface used by a Swift 6 host: data source/delegate adoption,
// cell and transformer subclasses, and the page control.
final class BannerCell6: FSPagerViewCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView?.contentMode = .scaleAspectFill
    }
}

final class FadeTransformer6: FSPagerViewTransformer {
    override func applyTransform(to attributes: FSPagerViewLayoutAttributes) {
        super.applyTransform(to: attributes)
        attributes.alpha = max(0.3, 1 - abs(attributes.position))
    }

    override func proposedInteritemSpacing() -> CGFloat {
        8
    }
}

final class BannerViewController6: UIViewController, FSPagerViewDataSource, FSPagerViewDelegate {
    private let pagerView = FSPagerView()
    private let pageControl = FSPageControl()
    private var titles = ["A", "B", "C"]

    override func viewDidLoad() {
        super.viewDidLoad()
        pagerView.register(BannerCell6.self, forCellWithReuseIdentifier: "banner")
        pagerView.dataSource = self
        pagerView.delegate = self
        pagerView.isInfinite = true
        pagerView.automaticSlidingInterval = 3
        pagerView.itemSize = CGSize(width: 280, height: 160)
        pagerView.decelerationDistance = FSPagerView.automaticDistance
        pagerView.transformer = FadeTransformer6(type: .linear)
        pageControl.numberOfPages = titles.count
        pageControl.setFillColor(.white, for: .selected)
        pageControl.setStrokeColor(.gray, for: .normal)
        view.addSubview(pagerView)
        view.addSubview(pageControl)
    }

    func numberOfItems(in pagerView: FSPagerView) -> Int {
        titles.count
    }

    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "banner", at: index)
        cell.textLabel?.text = titles[index]
        return cell
    }

    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        pagerView.deselectItem(at: index, animated: true)
        pagerView.scrollToItem(at: index, animated: true)
    }

    func pagerViewWillEndDragging(_ pagerView: FSPagerView, targetIndex: Int) {
        pageControl.currentPage = targetIndex
    }

    func pagerViewDidEndScrollAnimation(_ pagerView: FSPagerView) {
        pageControl.currentPage = pagerView.currentIndex
    }

    func refresh(with titles: [String]) async {
        let loaded = titles
        await MainActor.run {
            self.titles = loaded
            self.pageControl.numberOfPages = loaded.count
            self.pagerView.reloadData()
        }
    }
}
