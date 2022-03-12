import Foundation

extension HTTPURLResponse {
    var retryAfterInterval: TimeInterval? {
        return allHeaderFields["Retry-After"]
            .flatMap({ $0 as? String })
            .flatMap({ Int($0) })
            .map({ TimeInterval($0) })
    }
}

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

    var uploadIdentifier: WellsUploader.Identifier? {
        get {
            return allHTTPHeaderFields?["Wells-Upload-Identifier"]
        }
        mutating set {
            setValue(newValue, forHTTPHeaderField: "Wells-Upload-Identifier")
        }
    }
}
