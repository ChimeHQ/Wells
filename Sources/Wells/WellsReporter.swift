//
//  WellsReporter.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-09.
//

import Foundation
import os.log

public enum ReporterError: Error {
    case failedToCreateURL
}

public class WellsReporter {
    public static let shared = WellsReporter()
    private static let identifierHeader = "Wells-Upload-Identifier"
    public static let uploadFileExtension = "wellsdata"

    public let baseURL: URL
    private let uploader: WellsUploader
    private let logger: OSLog
    public var locationProvider: ReportLocationProvider

    public init(baseURL: URL = defaultDirectory, backgroundIdentifier: String? = WellsUploader.defaultBackgroundIdentifier) {
        self.logger = OSLog(subsystem: "io.stacksift.Wells", category: "Reporter")
        self.baseURL = baseURL
        self.uploader = WellsUploader(backgroundIdentifier: backgroundIdentifier)
        self.locationProvider = IdentifierExtensionLocationProvider(baseURL: baseURL,
                                                                    fileExtension: WellsReporter.uploadFileExtension)

        uploader.delegate = self
    }

    public var usingBackgroundUploads: Bool {
        return uploader.backgroundIdentifier != nil
    }

    private func defaultURL(for identifier: String) -> URL {
        return baseURL.appendingPathComponent(identifier).appendingPathExtension(WellsReporter.uploadFileExtension)
    }

    private func reportURL(for identifier: String) -> URL? {
        return locationProvider.reportURL(for: identifier)
    }

    public func submit(_ data: Data, uploadRequest: URLRequest) throws {
        let identifier = UUID().uuidString

        guard let fileURL = reportURL(for: identifier) else {
            throw ReporterError.failedToCreateURL
        }

        do {
            try createReportDirectoryIfNeeded()
            try data.write(to: fileURL)
        } catch {
            os_log("failed to write out data", log: self.logger, type: .error, String(describing: error))

            return
        }

        do {
            try submit(fileURL: fileURL, identifier: identifier, uploadRequest: uploadRequest)
        } catch {
            os_log("failed to begin submission process %{public}@", log: self.logger, type: .error, String(describing: error))

            removeFile(at: fileURL)
        }
    }

    public func submit(fileURL: URL, identifier: String, uploadRequest: URLRequest) throws {
        var request = uploadRequest

        // embed our header for background tracking
        request.addValue(identifier, forHTTPHeaderField: WellsReporter.identifierHeader)

        uploader.uploadFile(fileURL, using: request)
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

        guard let fileURL = reportURL(for: identifier) else {
            os_log("Failed to compute URL for %{public}@", log: self.logger, type: .error, identifier)

            return
        }

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
        return FileManager.default.bundleIdSubdirectoryURL(for: .cachesDirectory)
    }

    public static var defaultDirectory: URL {
        let baseURL = bundleScopedCachesDirectory ?? fallbackDirectory

        return baseURL.appendingPathComponent("io.stacksift.Wells")
    }
}
