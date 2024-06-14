import XCTest
@testable import StompClient

final class StompClientTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    
    func testStompCommandMakeHeader() {
        let command: StompCommand = .connect(host: "ws://localhost:8080")
        let headers = command.headers()
        
        XCTAssertEqual(
            headers,
            ["host": "ws://localhost:8080", "accept-version": "1.2"],
            "Host header should match"
        )
    }
}
