//
//  FSPagerViewExampleUITests.swift
//  FSPagerViewExampleUITests
//
//  Created by Wenchao Ding on 31/01/2017.
//  Copyright © 2017 Wenchao Ding. All rights reserved.
//

import XCTest

@MainActor
class FSPagerViewExampleUITests: XCTestCase {

    /// Opens every example from a fresh launch and swipes its pager.
    func testEveryExampleShowsItsPager() {
        let app = XCUIApplication()
        for example in ["Banner Example", "Transformer Example", "PageControl Example"] {
            // Relaunch instead of tapping Back: iPhone Duo draws the back control outside the navigation bar.
            app.launch()
            let row = app.staticTexts[example]
            XCTAssertTrue(row.waitForExistence(timeout: 10), example)
            row.tap()

            let pager = app.collectionViews.firstMatch
            XCTAssertTrue(pager.waitForExistence(timeout: 5), example)
            XCTAssertTrue(pager.cells.firstMatch.waitForExistence(timeout: 5), example)
            pager.swipeLeft()
            XCTAssertTrue(pager.cells.firstMatch.exists, example)

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = example
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

}
