import Foundation

extension URLRequest {
    var attemptCount: Int {
        get {
            return allHTTPHeaderFields?["Wells-Attempt"]
                .flatMap({ Int($0) }) ?? 0
        }
        mutating set {
            setValue(String(newValue), forHTTPHeaderField: "Wells-Attempt")
        }
    }

    var uploadIdentifier: String? {
        get {
            return allHTTPHeaderFields?["Wells-Upload-Identifier"]
        }
        mutating set {
            setValue(newValue, forHTTPHeaderField: "Wells-Upload-Identifier")
        }
    }
}
