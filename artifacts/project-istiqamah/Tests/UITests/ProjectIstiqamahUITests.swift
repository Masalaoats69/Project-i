import XCTest

final class ProjectIstiqamahUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreNavigationAndSwapEntryPoint() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Blocks"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progress"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        app.tabBars.buttons["Blocks"].tap()
        app.navigationBars.buttons["Add block"].tap()
        XCTAssertTrue(app.navigationBars["New Block"].waitForExistence(timeout: 5))
        // SwiftUI exposes the visible Start/End labels separately from the compact pickers.
        XCTAssertTrue(app.datePickers["blockEditor.startTime"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["blockEditor.endTime"].exists)
        app.navigationBars.buttons["Cancel"].tap()

        let swap = app.navigationBars.buttons["Swap schedules"]
        XCTAssertTrue(swap.waitForExistence(timeout: 2))
        swap.tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Blocks swap mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testBlockEditorDismissesKeyboardWithoutLosingInput() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Blocks"].tap()
        app.navigationBars.buttons["Add block"].tap()
        let name = app.textFields["blockEditor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Quiet practice")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.descendants(matching: .any)["blockEditor.duration"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "Quiet practice")
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["Dismiss keyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "Quiet practice")
        app.navigationBars.buttons["Cancel"].tap()
    }

}
