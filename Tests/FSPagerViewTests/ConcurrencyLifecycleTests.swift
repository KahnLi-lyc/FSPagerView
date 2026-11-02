import XCTest
import UIKit
@testable import FSPagerView

@MainActor
final class ConcurrencyLifecycleTests: XCTestCase {
    func testAutomaticSlidingFollowsWindowAndDragging() {
        let source = Source(count: 3)
        let pager = makePager(source: source)
        pager.automaticSlidingInterval = 10
        XCTAssertNotNil(pager.timer)
        let window = mount(pager)
        XCTAssertNotNil(pager.timer)
        pager.scrollViewWillBeginDragging(pager.collectionView)
        XCTAssertNil(pager.timer)
        var target = CGPoint.zero
        pager.scrollViewWillEndDragging(pager.collectionView, withVelocity: .zero, targetContentOffset: &target)
        XCTAssertNotNil(pager.timer)
        unmount(window)
        XCTAssertNil(pager.timer)
        pager.automaticSlidingInterval = 0
        XCTAssertNil(pager.timer)
    }

    // Animated scrolling does not render frames in an unhosted test bundle; the
    // visible advance is checked in a Simulator host app (see docs/VALIDATION.md).
    func testAutomaticSlidingTimerRepeatsOnMainRunLoop() throws {
        let source = Source(count: 3)
        let pager = makePager(source: source)
        let window = mount(pager)
        defer { unmount(window) }
        pager.reloadData()
        pager.layoutIfNeeded()
        pager.automaticSlidingInterval = 0.1
        let timer = try XCTUnwrap(pager.timer)
        let firstFireDate = timer.fireDate
        spinMainRunLoop(for: 0.35)
        XCTAssertTrue(timer.isValid)
        XCTAssertTrue(pager.timer === timer)
        XCTAssertGreaterThan(timer.fireDate.timeIntervalSince(firstFireDate), 0.15)
    }

    func testPendingTimerDoesNotRetainPagerAndStopsAfterRelease() throws {
        weak var weakPager: FSPagerView?
        var timer: Timer?
        autoreleasepool {
            let pager = makePager(source: Source(count: 3))
            pager.automaticSlidingInterval = 0.05
            timer = pager.timer
            weakPager = pager
        }
        XCTAssertNil(weakPager)
        XCTAssertEqual(timer?.isValid, true)
        spinMainRunLoop(for: 0.2)
        XCTAssertEqual(timer?.isValid, false)
    }

    func testMountedPagerIsReleasedAfterRemoval() {
        weak var weakPager: FSPagerView?
        let source = Source(count: 3)
        autoreleasepool {
            let pager = makePager(source: source)
            pager.automaticSlidingInterval = 1
            pager.transformer = FSPagerViewTransformer(type: .linear)
            let window = mount(pager)
            pager.reloadData()
            pager.layoutIfNeeded()
            unmount(window)
            weakPager = pager
        }
        XCTAssertNil(weakPager)
    }

    func testCellReleaseEndsFontObservation() throws {
        var label: UILabel?
        weak var weakCell: FSPagerViewCell?
        autoreleasepool {
            let cell = FSPagerViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            label = cell.textLabel
            weakCell = cell
        }
        XCTAssertNil(weakCell)
        label?.font = .systemFont(ofSize: 30)
        XCTAssertEqual(label?.font.pointSize, 30)
    }

    func testPageControlReleasedBeforePendingUpdate() {
        weak var weakControl: FSPageControl?
        autoreleasepool {
            let control = FSPageControl(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
            control.numberOfPages = 5
            control.currentPage = 2
            weakControl = control
        }
        XCTAssertNil(weakControl)
        spinMainRunLoop()
    }
}
