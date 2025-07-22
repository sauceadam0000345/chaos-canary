// In your file: InteractiveUITests.swift

import XCTest

final class InteractiveUITests: XCTestCase {

    func testHappyPathNetworkRequest() throws {
        // 1. Launch the app
        let app = XCUIApplication()
        app.launch()

        // 2. Find the button and label by their stable accessibility identifiers.
        let makeRequestButton = app.buttons["MakeRequestButton"]
        let statusLabel = app.staticTexts["StatusLabel"]

        // 3. Tap the button to trigger the network call.
        makeRequestButton.tap()

        // 4. Manually poll for the label's text to change.
        // This is our most aggressive diagnostic approach.
        var labelShowsSuccess = false
        
        // Poll for up to 30 seconds.
        for i in 0..<30 {
            // In each loop, get the current label text from the accessibility layer.
            let currentLabelText = statusLabel.label
            print("--- Poll #\(i): Checking label. Current value is: '\(currentLabelText)' ---")

            if currentLabelText.contains("Success: 200") {
                labelShowsSuccess = true
                print("--- SUCCESS: Label updated correctly! ---")
                break
            }
            // Wait for 1 second before the next check.
            sleep(1)
        }

        // 5. Assert that the label's text was updated.
        // If it failed, the logs will now contain a second-by-second history of what the label's text was.
        if !labelShowsSuccess {
            print("--- DEBUG: FINAL UI HIERARCHY ---")
            print(app.debugDescription)
            print("---------------------------------")
        }
        
        XCTAssert(labelShowsSuccess, "The status label's text did not update to 'Success: 200' within the timeout. Check the polling logs for its value.")
    }
}
