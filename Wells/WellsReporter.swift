//
//  WellsReporter.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-09.
//

import Foundation
import os.log

public protocol WellsReporterDelegate: AnyObject {
    func makeURLRequest(for reporter: WellsReporter, fileURL: URL) -> URLRequest?
    func makeFileURL(for reporter: WellsReporter, identifier: String) -> URL?
}

public enum ReporterError: Error {
    case noRequest
}

public class WellsReporter {
    public static let shared = WellsReporter()
    private static let identifierHeader = "Wells-Upload-Identifier"
    public static let uploadFileExtension = "wellsdata"

    public weak var delegate: WellsReporterDelegate?
    public let baseURL: URL
    private let uploader: WellsUploader
    private let logger: OSLog

    public init(baseURL: URL = defaultDirectory, backgroundIdentifier: String = WellsUploader.defaultBackgroundIdentifier) {
        self.logger = OSLog(subsystem: "com.chimehq.Wells", category: "Reporter")
        self.baseURL = baseURL
        self.uploader = WellsUploader(backgroundIdentifier: backgroundIdentifier)

        uploader.delegate = self
    }

    private func defaultURL(for identifier: String) -> URL {
        return baseURL.appendingPathComponent(identifier).appendingPathExtension(WellsReporter.uploadFileExtension)
    }

    private func reportURL(for identifier: String) -> URL {
        return delegate?.makeFileURL(for: self, identifier: identifier) ?? defaultURL(for: identifier)
    }

    public func submit(_ data: Data) {
        let identifier = UUID().uuidString
        let fileURL = reportURL(for: identifier)

        do {
            try createReportDirectoryIfNeeded()
            try data.write(to: fileURL)
        } catch {
            os_log("failed to write out data", log: self.logger, type: .error, String(describing: error))

            return
        }

        do {
            try submit(url: fileURL, identifier: identifier)
        } catch {
            os_log("failed to begin submission process %{public}@", log: self.logger, type: .error, String(describing: error))

            removeFile(at: fileURL)
        }
    }

    public func submit(url: URL, identifier: String) throws {
        guard var request = delegate?.makeURLRequest(for: self, fileURL: url) else {
            throw ReporterError.noRequest
        }

        // embed our header for background tracking
        request.addValue(identifier, forHTTPHeaderField: WellsReporter.identifierHeader)

        uploader.uploadFile(url, using: request)
    }

    private func createReportDirectoryIfNeeded() throws {
        if FileManager.default.directoryExists(at: baseURL) {
            return
        }

        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func removeFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            os_log("failed to remove log at %{public}@ %{public}@", log: self.logger, type: .error, url.path, String(describing: error))
        }
    }
}

extension WellsReporter: WellsUploaderDelegate {
    public func finishedUpload(of identifier: WellsUploader.Identifier, with error: Error?, by uploader: WellsUploader) {
        if let e = error {
            os_log("Failed to submit report: %{public}@ - %{public}@", log: self.logger, type: .error, identifier, String(describing: e))
        } else {
            os_log("Submitted report successfully: %{public}@", log: self.logger, type: .error, identifier)
        }

        let fileURL = reportURL(for: identifier)

        removeFile(at: fileURL)
    }

    public func uploadIdentifier(for request: URLRequest, with uploader: WellsUploader) -> WellsUploader.Identifier? {
        return request.allHTTPHeaderFields?[WellsReporter.identifierHeader]
    }
}

extension WellsReporter {
    private static var fallbackDirectory: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private static var bundleScopedCachesDirectory: URL? {
        return FileManager.default.bundleIdScopedURL(for: .cachesDirectory)
    }

    public static var defaultDirectory: URL {
        let baseURL = bundleScopedCachesDirectory ?? fallbackDirectory

        return baseURL.appendingPathComponent("com.chimehq.Wells")
    }
}
