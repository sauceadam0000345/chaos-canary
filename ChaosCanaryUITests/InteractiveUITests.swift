// In your file: InteractiveUITests.swift

import XCTest

final class InteractiveUITests: XCTestCase {

    // This function runs before each test in this class.
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        // Force the device into portrait mode to ensure a stable UI layout.
        XCUIDevice.shared.orientation = .portrait
    }

    //========================================#
    // Test 1: Happy Path                     #
    //========================================#
    // This test verifies the normal, successful network request.
    // It should be run against the "Happy Path" or "Normal Proxy" suites.
    func testHappyPathNetworkRequest() throws {
        let app = XCUIApplication()
        app.launch()
        
        app.buttons["MakeRequestButton"].tap()
        
        let successLabel = app.staticTexts["Success: 200"]
        let successLabelExists = successLabel.waitForExistence(timeout: 30.0)
        
        XCTAssert(successLabelExists, "The 'Success: 200' label did not appear within the timeout.")
    }

    //========================================#
    // Test 2: API Failure Chaos Experiment   #
    //========================================#
    // This test asserts that the app correctly displays a failure message
    // when the API returns a 503 error.
    // It should be run against the "API Failure Chaos" suite.
    func testApiFailureChaosExperiment() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["MakeRequestButton"].tap()

        // Assert that the expected failure state appears.
        let failureLabel = app.staticTexts["Failure: 503"]
        let failureLabelExists = failureLabel.waitForExistence(timeout: 30.0)

        XCTAssert(failureLabelExists, "The 'Failure: 503' label did not appear. The app did not handle the API failure correctly.")
    }
    
    //========================================#
    // Test 3: API Latency Chaos Experiment   #
    //========================================#
    // This test asserts that a network request takes longer than expected
    // when latency is injected.
    // It should be run against the "Latency Chaos" suite.
    func testApiLatencyChaosExperiment() throws {
        let app = XCUIApplication()
        app.launch()

        let makeRequestButton = app.buttons["MakeRequestButton"]
        
        // Record the time before we tap the button.
        let startTime = Date()
        
        makeRequestButton.tap()

        // Wait for the success label to appear.
        let successLabel = app.staticTexts["Success: 200"]
        let successLabelExists = successLabel.waitForExistence(timeout: 30.0)
        
        // Record the time after the request completes.
        let endTime = Date()
        
        // Calculate the duration.
        let duration = endTime.timeIntervalSince(startTime)
        
        print("--- Network request duration: \(duration) seconds ---")

        // Assert that the success label appeared (the request did eventually succeed).
        XCTAssert(successLabelExists, "The 'Success: 200' label did not appear within the timeout.")
        
        // Assert that the request took longer than the injected delay.
        // We use 4.0s instead of 5.0s to account for slight timing variations.
        XCTAssert(duration > 4.0, "The network request completed too quickly. Expected >5s, but it took \(duration)s.")
    }
}
