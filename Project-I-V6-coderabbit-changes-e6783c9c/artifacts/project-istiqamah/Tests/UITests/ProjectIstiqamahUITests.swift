import XCTest

final class ProjectIstiqamahUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreNavigationAndReorderEntryPoint() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Blocks"].exists)
        XCTAssertTrue(app.tabBars.buttons["Progress"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        app.tabBars.buttons["Blocks"].tap()
        app.navigationBars.buttons["Add block"].tap()
        XCTAssertTrue(app.datePickers["Start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["End"].exists)
        app.navigationBars.buttons["Cancel"].tap()

        let reorder = app.navigationBars.buttons["Reorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 2))
        reorder.tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Blocks reorder mode"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
