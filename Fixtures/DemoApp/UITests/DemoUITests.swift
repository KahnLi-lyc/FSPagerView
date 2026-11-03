import XCTest

@MainActor
final class DemoUITests: XCTestCase {
    func testAnimatedCollapseAndExpandKeepsPage() {
        for container in ["autolayout", "stack"] {
            for collapse in ["width", "height"] {
                for direction in ["horizontal", "vertical"] {
                    for infinite in [false, true] {
                        let context = "\(container) collapse=\(collapse) \(direction) infinite=\(infinite)"
                        let app = launch(container: container, collapse: collapse, direction: direction, infinite: infinite)
                        showPage(2, in: app, context)
                        app.buttons["collapse"].tap()
                        waitForStatus("index=2 state=collapsed", in: app, context)
                        app.buttons["expand"].tap()
                        waitForStatus("index=2 state=expanded", in: app, context)
                        assertPageCentered(2, in: app, context)
                        attachScreenshot(of: app, named: context)
                        app.terminate()
                    }
                }
            }
        }
    }

    func testRotationKeepsPage() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for direction in ["horizontal", "vertical"] {
            let app = launch(container: "autolayout", collapse: "width", direction: direction, infinite: true)
            showPage(2, in: app, direction)
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                let context = "\(direction) \(orientation == .portrait ? "portrait" : "landscape")"
                XCUIDevice.shared.orientation = orientation
                assertPageCentered(2, in: app, context)
                waitForStatus("index=2 state=expanded", in: app, context)
                attachScreenshot(of: app, named: context)
            }
            app.terminate()
        }
    }

    func testAccessibility() throws {
        let app = launch(container: "autolayout", collapse: "height", direction: "horizontal", infinite: false)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == 'Page 0'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["next"].isHittable)
        if #available(iOS 17.0, *) {
            try app.performAccessibilityAudit()
        }
    }

    // MARK: - Helpers

    private func launch(container: String, collapse: String, direction: String, infinite: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-container", container, "-collapse", collapse, "-direction", direction, "-infinite", infinite ? "1" : "0"]
        app.launch()
        waitForStatus("index=0 state=expanded", in: app, "launch")
        return app
    }

    private func showPage(_ page: Int, in app: XCUIApplication, _ context: String) {
        for index in 1...page {
            app.buttons["next"].tap()
            waitForStatus("index=\(index) state=expanded", in: app, context)
        }
        assertPageCentered(page, in: app, context)
    }

    private func waitForStatus(_ text: String, in app: XCUIApplication, _ context: String) {
        let status = app.staticTexts["status"]
        let matched = waitUntil { status.exists && status.label == text }
        XCTAssertTrue(matched, "\(context): status is \"\(status.exists ? status.label : "missing")\", expected \"\(text)\"")
    }

    /// The page's cell must sit exactly in the middle of the pager, i.e. no offset drift after a resize.
    private func assertPageCentered(_ page: Int, in app: XCUIApplication, _ context: String) {
        let pager = app.collectionViews.firstMatch
        let cell = app.cells.containing(NSPredicate(format: "label == %@", "Page \(page)")).firstMatch
        let centered = waitUntil {
            guard pager.exists, cell.exists else {
                return false
            }
            return abs(cell.frame.midX - pager.frame.midX) <= 1 && abs(cell.frame.midY - pager.frame.midY) <= 1
        }
        let description = pager.exists && cell.exists ? "cell \(cell.frame) pager \(pager.frame)" : "pager or cell missing"
        XCTAssertTrue(centered, "\(context): Page \(page) is not centered, \(description)")
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() > deadline {
                return false
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return true
    }

    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
