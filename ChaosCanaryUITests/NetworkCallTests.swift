// In your file: NetworkCallTests.swift

import XCTest

class NetworkCallTests: XCTestCase {

    // This test's only job is to make a network call and prove it can be intercepted.
    func testExplicitNetworkCallToPublicAPI() throws {
        print("--- FIRING EXPLICIT NETWORK CALL ---")

        // Use a new, reliable, public API endpoint for testing.
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1") else {
            XCTFail("Invalid URL.")
            return
        }

        let expectation = XCTestExpectation(description: "Fetch data from public API")

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("--- Received HTTP Status Code: \(httpResponse.statusCode) ---")
                // A 200 OK means the proxy successfully forwarded the request and got a good response.
                XCTAssertEqual(httpResponse.statusCode, 200, "Expected a 200 OK. If this fails, check the mitmproxy log for errors.")
            } else if let error = error {
                 XCTFail("Network request failed with error: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        task.resume()
        wait(for: [expectation], timeout: 30.0)
    }
}
