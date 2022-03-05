//
//  NetworkResponse.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-02.
//

import Foundation

public enum NetworkResponse {
    case failed(Error)
    case rejected
    case retry
    case success(Int)
}

extension NetworkResponse: CustomStringConvertible {
    public var description: String {
        switch self {
        case .failed(let e): return "failed (\(e))"
        case .rejected: return "rejected"
        case .retry: return "retry"
        case .success(let code): return "success (\(code))"
        }
    }
}

public enum NetworkResponseError: Error {
    case noResponseOrError
    case noHTTPResponse
    case httpReponseInvalid
    case requestInvalid
}

public extension NetworkResponse {
    init(response: URLResponse?, error: Error? = nil) {
        if let e = error {
            self = NetworkResponse.failed(e)
            return
        }

        guard let response = response else {
            self = NetworkResponse.failed(NetworkResponseError.noResponseOrError)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            self = NetworkResponse.failed(NetworkResponseError.noHTTPResponse)
            return
        }

        let code = httpResponse.statusCode

        switch code {
        case 0..<200:
            self = NetworkResponse.failed(NetworkResponseError.httpReponseInvalid)
        case 200, 201, 202, 204:
            self = NetworkResponse.success(code)
        case 408, 429, 500, 502, 503, 504:
            self = NetworkResponse.retry
        default:
            self = NetworkResponse.rejected
        }
    }

    init(task: URLSessionTask, error: Error? = nil) {
        self.init(response: task.response, error: error)
    }
}
