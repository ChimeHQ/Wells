import Foundation
import os.log

public enum ReporterError: Error {
    case failedToCreateURL
}

public class WellsReporter {
    public static let shared = WellsReporter()
    public static let uploadFileExtension = "wellsdata"
    private static let maximumAccountCount = 5
    private static let maximumLogAge: TimeInterval = 2.0 * 24.0 * 60.0 * 60.0
    public lazy var existingLogHandler: (URL, Date) -> Void = { url, date in
        self.handleExistingLog(at: url, date: date)
    }

    public let baseURL: URL
    private let uploader: WellsUploader
    private let logger: OSLog
    public var locationProvider: ReportLocationProvider

    public init(baseURL: URL = defaultDirectory, backgroundIdentifier: String? = WellsUploader.defaultBackgroundIdentifier) {
        self.logger = OSLog(subsystem: "com.chimehq.Wells", category: "Reporter")
        self.baseURL = baseURL
        self.uploader = WellsUploader(backgroundIdentifier: backgroundIdentifier)
        self.locationProvider = IdentifierExtensionLocationProvider(baseURL: baseURL,
                                                                    fileExtension: WellsReporter.uploadFileExtension)

        uploader.delegate = self

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), qos: .background) {
            self.handleExistingLogs()
        }
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

        try createReportDirectoryIfNeeded()

        try data.write(to: fileURL)

        submit(fileURL: fileURL, identifier: identifier, uploadRequest: uploadRequest)
    }

    public func submit(fileURL: URL, identifier: String, uploadRequest: URLRequest) {
        var request = uploadRequest

        // embed our header for background tracking
        request.uploadIdentifier = identifier

        uploader.uploadFile(fileURL, using: request)
    }

    public func createReportDirectoryIfNeeded() throws {
        if FileManager.default.directoryExists(at: baseURL) {
            return
        }

        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
    }

    func handleExistingLogs() {
        let urls = try? FileManager.default.contentsOfDirectory(at: baseURL,
                                                                includingPropertiesForKeys: [.creationDateKey])

        guard let urls = urls else {
            return
        }

        for url in urls {
            let values = try? url.resourceValues(forKeys: [.creationDateKey])
            let date = values?.creationDate ?? Date.distantPast

            self.existingLogHandler(url, date)
        }
    }

    private func removeFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            os_log("failed to remove log at %{public}@ %{public}@", log: self.logger, type: .error, url.path, String(describing: error))
        }
    }

    private func removeFile(with identifier: WellsUploader.Identifier) {
        guard let fileURL = reportURL(for: identifier) else {
            os_log("Failed to compute URL for %{public}@", log: self.logger, type: .error, identifier)

            return
        }

        removeFile(at: fileURL)
    }

    private func retrySubmission(of identifier: WellsUploader.Identifier, after interval: TimeInterval, with request: URLRequest) {
        guard let fileURL = reportURL(for: identifier) else {
            os_log("Failed to compute URL for %{public}@", log: logger, type: .error, identifier)

            return
        }

        let count = request.attemptCount

        if count >= WellsReporter.maximumAccountCount {
            os_log("Exceeded maximum retry count for %{public}@", log: logger, type: .error, identifier)

            removeFile(at: fileURL)

            return
        }

        let delay = Int(max(interval, 60.0))

        os_log("Retrying submission after %{public}d %{public}@", log: logger, type: .info, delay, identifier)

        var newRequest = request

        newRequest.attemptCount = count + 1

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), qos: .background) {
            self.submit(fileURL: fileURL, identifier: identifier, uploadRequest: newRequest)
        }
    }

    private func handleExistingLog(at url: URL, date: Date) {
        let oldDate = Date().addingTimeInterval(-WellsReporter.maximumLogAge)

        guard date < oldDate else { return }

        os_log("removing old log %{public}@", log: logger, type: .info, url.path)
        removeFile(at: url)
    }
}

extension WellsReporter: WellsUploaderDelegate {
    public func finishedUpload(of identifier: WellsUploader.Identifier, with error: NetworkResponseError?, by uploader: WellsUploader) {
        switch error {
        case .transientFailure(let interval, let request):
            retrySubmission(of: identifier, after: interval, with: request)

            return
        case nil:
            os_log("Submitted report successfully: %{public}@", log: self.logger, type: .error, identifier)
        case let e?:
            os_log("Failed to submit report: %{public}@ - %{public}@", log: self.logger, type: .error, identifier, String(describing: e))
        }

        removeFile(with: identifier)
    }

    public func uploadIdentifier(for request: URLRequest, with uploader: WellsUploader) -> WellsUploader.Identifier? {
        return request.uploadIdentifier
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

        return baseURL.appendingPathComponent("com.chimehq.Wells")
    }
}
