import UIKit
@testable import FSPagerView

@MainActor
final class Source: NSObject, FSPagerViewDataSource, FSPagerViewDelegate {
    var count: Int
    var scrolls = 0
    var selected: [Int] = []

    init(count: Int) {
        self.count = count
    }

    func numberOfItems(in pagerView: FSPagerView) -> Int {
        count
    }

    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        cell.textLabel?.text = "\(index)"
        return cell
    }

    func pagerViewDidScroll(_ pagerView: FSPagerView) {
        scrolls += 1
    }

    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        selected.append(index)
    }
}

@MainActor
func makePager(source: Source, frame: CGRect = CGRect(x: 0, y: 0, width: 320, height: 200)) -> FSPagerView {
    let pager = FSPagerView(frame: frame)
    pager.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
    pager.dataSource = source
    pager.delegate = source
    return pager
}

@MainActor
func mount(_ view: UIView) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
    let controller = UIViewController()
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.addSubview(view)
    controller.view.layoutIfNeeded()
    view.layoutIfNeeded()
    return window
}

@MainActor
func unmount(_ window: UIWindow) {
    window.rootViewController?.view.subviews.forEach { $0.removeFromSuperview() }
    window.isHidden = true
    window.rootViewController = nil
}

func spinMainRunLoop(for interval: TimeInterval = 0.05) {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: interval))
}
