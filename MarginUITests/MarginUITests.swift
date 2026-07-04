//
//  MarginUITests.swift
//  MarginUITests
//
//  Created by Brayden Sally on 2026-07-02.
//

import XCTest

final class MarginUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // Note: `addNotebook()`/`addPage()` in the app select the newly created item
    // immediately, so NavigationSplitView shows the next column (content/detail)
    // without any extra tap — these tests just wait for that column to appear.

    @MainActor
    func testAddingNotebookShowsNewRow() throws {
        let app = XCUIApplication()
        app.launch()

        let addNotebookButton = app.buttons["New Notebook"]
        XCTAssertTrue(addNotebookButton.waitForExistence(timeout: 5))
        addNotebookButton.tap()

        // Selecting the new notebook navigates to its page list, whose custom
        // header renders the notebook's title as a static text.
        XCTAssertTrue(app.staticTexts["Untitled Notebook"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddingPageShowsNewRowAndDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let addNotebookButton = app.buttons["New Notebook"]
        XCTAssertTrue(addNotebookButton.waitForExistence(timeout: 5))
        addNotebookButton.tap()

        XCTAssertTrue(app.staticTexts["Untitled Notebook"].waitForExistence(timeout: 5))

        let addPageButton = app.buttons["New Page"]
        XCTAssertTrue(addPageButton.waitForExistence(timeout: 5))
        addPageButton.tap()

        // "Untitled Page" surfaces either as the page list row (regular width,
        // where content and detail columns are both visible) or as the detail
        // column's title (compact width, where selecting a page navigates
        // straight to it) — match any element carrying that label.
        let untitledPage = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Untitled Page"))
            .firstMatch
        XCTAssertTrue(untitledPage.waitForExistence(timeout: 5))

        XCTAssertFalse(app.staticTexts["Nothing Open"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
