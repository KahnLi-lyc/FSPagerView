import XCTest
import UIKit
@testable import FSPagerView

@MainActor
final class PackageRegressionTests: XCTestCase {
    func testPrivacyManifestIsInSwiftPackageBundle() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(NSDictionary(contentsOf: url))
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
    }

    func testFiniteAndInfiniteSectionCounts() {
        let source = Source(count: 5)
        let pager = makePager(source: source)
        let window = mount(pager)
        defer { unmount(window) }
        pager.reloadData()
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.collectionView.numberOfSections, 1)
        XCTAssertEqual(pager.collectionView.numberOfItems(inSection: 0), 5)

        pager.isInfinite = true
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.collectionView.numberOfSections, Int(Int16.max) / 5)

        source.count = 1
        pager.removesInfiniteLoopForSingleItem = true
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.collectionView.numberOfSections, 1)

        source.count = 0
        pager.reloadData()
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.collectionView.numberOfSections, 0)
    }

    func testScrollToItemUpdatesCurrentIndexAndCells() throws {
        let source = Source(count: 4)
        let pager = makePager(source: source)
        let window = mount(pager)
        defer { unmount(window) }
        pager.reloadData()
        pager.layoutIfNeeded()
        pager.scrollToItem(at: 2, animated: false)
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.currentIndex, 2)
        XCTAssertEqual(pager.scrollOffset, 2, accuracy: 0.001)
        let cell = try XCTUnwrap(pager.cellForItem(at: 2))
        XCTAssertEqual(cell.textLabel?.text, "2")
        XCTAssertEqual(pager.index(for: cell), 2)
    }

    func testInfiniteScrollWrapsIndices() {
        let source = Source(count: 3)
        let pager = makePager(source: source)
        pager.isInfinite = true
        let window = mount(pager)
        defer { unmount(window) }
        pager.reloadData()
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.currentIndex, 0)
        pager.scrollToItem(at: 2, animated: false)
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.currentIndex, 2)
        pager.scrollToItem(at: 0, animated: false)
        pager.layoutIfNeeded()
        XCTAssertEqual(pager.currentIndex, 0)
    }

    func testCollapseAndExpandKeepsCurrentPage() {
        let expanded = CGSize(width: 320, height: 200)
        let collapsedSizes = [CGSize.zero, CGSize(width: 0, height: 200), CGSize(width: 320, height: 0)]
        for direction in [FSPagerView.ScrollDirection.horizontal, .vertical] {
            for isInfinite in [false, true] {
                for collapsed in collapsedSizes {
                    let context = "\(direction) infinite=\(isInfinite) collapsed=\(collapsed)"
                    let source = Source(count: 4)
                    let pager = makePager(source: source)
                    pager.scrollDirection = direction
                    pager.isInfinite = isInfinite
                    let window = mount(pager)
                    pager.reloadData()
                    pager.layoutIfNeeded()
                    pager.scrollToItem(at: 2, animated: false)
                    pager.layoutIfNeeded()
                    XCTAssertEqual(pager.currentIndex, 2, context)

                    pager.frame.size = collapsed
                    pager.layoutIfNeeded()
                    XCTAssertEqual(pager.collectionView.frame.size, collapsed, context)
                    XCTAssertEqual(pager.currentIndex, 2, context)

                    pager.frame.size = expanded
                    pager.layoutIfNeeded()
                    XCTAssertEqual(pager.currentIndex, 2, context)
                    XCTAssertEqual(pager.scrollOffset, 2, accuracy: 0.001, context)
                    XCTAssertEqual(pager.cellForItem(at: 2)?.textLabel?.text, "2", context)
                    unmount(window)
                }
            }
        }
    }

    func testResizeKeepsCurrentPageCentered() {
        let sizes = [CGSize(width: 100, height: 120), CGSize(width: 718, height: 300), CGSize(width: 320, height: 200)]
        for direction in [FSPagerView.ScrollDirection.horizontal, .vertical] {
            for isInfinite in [false, true] {
                let source = Source(count: 5)
                let pager = makePager(source: source)
                pager.scrollDirection = direction
                pager.isInfinite = isInfinite
                let window = mount(pager)
                pager.reloadData()
                pager.layoutIfNeeded()
                pager.scrollToItem(at: 2, animated: false)
                pager.layoutIfNeeded()
                for size in sizes {
                    let context = "\(direction) infinite=\(isInfinite) size=\(size)"
                    // Dynamic Type, split view and stack views resize the pager without an animation.
                    pager.frame.size = size
                    pager.layoutIfNeeded()
                    let section = isInfinite ? pager.collectionView.numberOfSections / 2 : 0
                    let expected = pager.collectionViewLayout.contentOffset(for: IndexPath(item: 2, section: section))
                    XCTAssertEqual(pager.currentIndex, 2, context)
                    XCTAssertEqual(pager.collectionView.contentOffset.x, expected.x, accuracy: 0.5, context)
                    XCTAssertEqual(pager.collectionView.contentOffset.y, expected.y, accuracy: 0.5, context)
                }
                unmount(window)
            }
        }
    }

    func testBoundsChangeTargetsCurrentPage() {
        for direction in [FSPagerView.ScrollDirection.horizontal, .vertical] {
            for isInfinite in [false, true] {
                let context = "\(direction) infinite=\(isInfinite)"
                let source = Source(count: 5)
                let pager = makePager(source: source)
                pager.scrollDirection = direction
                pager.isInfinite = isInfinite
                let window = mount(pager)
                pager.reloadData()
                pager.layoutIfNeeded()
                pager.scrollToItem(at: 2, animated: false)
                pager.layoutIfNeeded()

                // A rotation resizes the pager inside an animation, and UIKit then asks the layout for a target offset.
                UIView.animate(withDuration: 0.3) {
                    pager.frame.size = CGSize(width: 718, height: 300)
                    pager.layoutIfNeeded()
                }
                let layout = pager.collectionViewLayout!
                let section = isInfinite ? pager.collectionView.numberOfSections / 2 : 0
                let expected = layout.contentOffset(for: IndexPath(item: 2, section: section))
                let proposed = CGPoint(x: expected.x / 2, y: expected.y / 2)
                XCTAssertEqual(layout.targetContentOffset(forProposedContentOffset: proposed), expected, context)
                XCTAssertEqual(pager.currentIndex, 2, context)
                unmount(window)
            }
        }
    }

    func testSelectionReportsLogicalIndex() {
        let source = Source(count: 3)
        let pager = makePager(source: source)
        pager.isInfinite = true
        let window = mount(pager)
        defer { unmount(window) }
        pager.reloadData()
        pager.layoutIfNeeded()
        let section = pager.collectionView.numberOfSections / 2
        pager.collectionView(pager.collectionView, didSelectItemAt: IndexPath(item: 1, section: section))
        XCTAssertEqual(source.selected, [1])
    }

    func testEveryTransformerTypeProducesFiniteAttributes() {
        let types: [FSPagerViewTransformerType] = [.crossFading, .zoomOut, .depth, .overlap, .linear, .coverFlow, .ferrisWheel, .invertedFerrisWheel, .cubic]
        for direction in [FSPagerView.ScrollDirection.horizontal, .vertical] {
            for type in types {
                let source = Source(count: 5)
                let pager = makePager(source: source)
                pager.itemSize = CGSize(width: 200, height: 150)
                pager.scrollDirection = direction
                pager.transformer = FSPagerViewTransformer(type: type)
                let window = mount(pager)
                pager.reloadData()
                pager.layoutIfNeeded()
                let attributes = pager.collectionViewLayout.layoutAttributesForElements(in: pager.collectionView.bounds.insetBy(dx: -400, dy: -400)) ?? []
                XCTAssertFalse(attributes.isEmpty, "\(type) \(direction)")
                for attribute in attributes {
                    XCTAssertTrue(attribute.alpha.isFinite && attribute.frame.origin.x.isFinite, "\(type) \(direction)")
                }
                unmount(window)
            }
        }
    }

    func testTransformerKeepsUpstreamDefaults() {
        let source = Source(count: 3)
        let pager = makePager(source: source)
        pager.itemSize = CGSize(width: 100, height: 100)
        let zoomOut = FSPagerViewTransformer(type: .zoomOut)
        XCTAssertEqual(zoomOut.minimumScale, 0.85)
        XCTAssertEqual(FSPagerViewTransformer(type: .depth).minimumScale, 0.5)
        let overlap = FSPagerViewTransformer(type: .overlap)
        pager.transformer = overlap
        XCTAssertTrue(overlap.pagerView === pager)
        XCTAssertEqual(overlap.proposedInteritemSpacing(), 100 * -0.65 * 0.6, accuracy: 0.0001)

        let attributes = FSPagerViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attributes.size = CGSize(width: 100, height: 100)
        attributes.position = 0.5
        pager.transformer = FSPagerViewTransformer(type: .crossFading)
        pager.transformer?.applyTransform(to: attributes)
        XCTAssertEqual(attributes.alpha, 0.5, accuracy: 0.0001)
        XCTAssertEqual(attributes.zIndex, 1)
    }

    func testLayoutAttributesEqualityAndCopyIncludePosition() throws {
        let attributes = FSPagerViewLayoutAttributes(forCellWith: IndexPath(item: 1, section: 0))
        attributes.position = 0.25
        let copy = try XCTUnwrap(attributes.copy() as? FSPagerViewLayoutAttributes)
        XCTAssertEqual(copy.position, 0.25)
        XCTAssertTrue(attributes.isEqual(copy))
        copy.position = 0.5
        XCTAssertFalse(attributes.isEqual(copy))
        XCTAssertFalse(attributes.isEqual(UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 1, section: 0))))
    }

    func testPageControlCreatesIndicatorsAndClampsCurrentPage() {
        let control = FSPageControl(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        control.currentPage = 4
        control.numberOfPages = 3
        spinMainRunLoop()
        XCTAssertEqual(indicators(of: control).count, 3)
        XCTAssertEqual(control.currentPage, 2)

        control.setFillColor(.red, for: .selected)
        control.setFillColor(.blue, for: .normal)
        control.setAlpha(0.5, for: .normal)
        spinMainRunLoop()
        XCTAssertEqual(indicators(of: control)[2].fillColor, UIColor.red.cgColor)
        XCTAssertEqual(indicators(of: control)[0].fillColor, UIColor.blue.cgColor)
        XCTAssertEqual(indicators(of: control)[0].opacity, 0.5)

        control.hidesForSinglePage = true
        control.numberOfPages = 1
        spinMainRunLoop()
        XCTAssertEqual(indicators(of: control).count, 1)
        XCTAssertTrue(control.subviews.first?.isHidden == true)
    }

    private func indicators(of control: FSPageControl) -> [CAShapeLayer] {
        control.subviews.first?.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
    }

    func testControlStateKeysAreDistinct() {
        var values: [UIControl.State: Int] = [:]
        values[.normal] = 0
        values[.selected] = 1
        values[[.selected, .highlighted]] = 2
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[.selected], 1)
        XCTAssertEqual(values[[.highlighted, .selected]], 2)
    }

    func testCellRelayoutsTextLabelWhenFontChanges() throws {
        let cell = FSPagerViewCell(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let label = try XCTUnwrap(cell.textLabel)
        XCTAssertTrue(label.adjustsFontForContentSizeCategory)
        cell.layoutIfNeeded()
        label.font = .systemFont(ofSize: 20)
        cell.layoutIfNeeded()
        XCTAssertEqual(label.superview?.frame.height ?? 0, 30, accuracy: 0.001)
        label.font = .systemFont(ofSize: 40)
        cell.layoutIfNeeded()
        XCTAssertEqual(label.superview?.frame.height ?? 0, 60, accuracy: 0.001)
    }

    func testCellRelayoutsTextLabelForLargerContentSize() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("traitOverrides requires iOS 17")
        }
        let cell = FSPagerViewCell(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let label = try XCTUnwrap(cell.textLabel)
        label.text = "Page 0"
        let window = mount(cell)
        defer { unmount(window) }
        cell.layoutIfNeeded()
        let regularHeight = label.frame.height

        cell.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        cell.updateTraitsIfNeeded()
        cell.layoutIfNeeded()
        XCTAssertGreaterThan(label.font.pointSize, 40)
        XCTAssertGreaterThan(label.frame.height, regularHeight)
        XCTAssertGreaterThanOrEqual(label.frame.height, label.font.lineHeight)
    }
}
