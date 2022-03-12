import XCTest
import Wells
import Foundation

final class NetworkResponseTests: XCTestCase {
    func testDefaultRetryAfter() throws {
        let urlResponse = HTTPURLResponse(url: URL(string: "http://example.com")!,
                                          statusCode: 429,
                                          httpVersion: "1.1",
                                          headerFields: [:])

        let response = NetworkResponse(response: urlResponse)

        switch response {
        case .retry:
            break
        default:
            XCTFail()
        }
    }
}
