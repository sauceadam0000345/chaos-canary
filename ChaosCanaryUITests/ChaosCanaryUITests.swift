// In ChaosCanaryUITests.swift

import XCTest

final class ChaosCanaryUITests: XCTestCase {
    func testAppLaunch() throws {
        // This test simply launches the app and verifies it doesn't crash.
        // Its only purpose is to see if the test runner can start.
        let app = XCUIApplication()
        app.launch()
        
        // Add a small wait to ensure the app has time to fully launch.
        sleep(5)
        
        // A simple assertion to make it a valid test.
        XCTAssert(app.state == .runningForeground, "The app did not launch successfully.")
    }
}
