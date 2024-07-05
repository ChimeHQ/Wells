import XCTest
@testable import Wells

final class HTTPHeaderTests: XCTestCase {
    func testAttemptCount() throws {
        var request = URLRequest(url: URL(string: "http://example.com")!)

        XCTAssertEqual(request.attemptCount, 0)

        request.addValue("5", forHTTPHeaderField: "Wells-Attempt")

        XCTAssertEqual(request.attemptCount, 5)

        request.attemptCount = 2

        XCTAssertEqual(request.attemptCount, 2)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Wells-Attempt"), "2")
    }

    func testBackgroundIdentifier() throws {
        var request = URLRequest(url: URL(string: "http://example.com")!)

        XCTAssertEqual(request.uploadIdentifier, nil)

        request.addValue("abc", forHTTPHeaderField: "Wells-Upload-Identifier")

        XCTAssertEqual(request.uploadIdentifier, "abc")

        request.uploadIdentifier = "def"

        XCTAssertEqual(request.uploadIdentifier, "def")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Wells-Upload-Identifier"), "def")
    }
}
