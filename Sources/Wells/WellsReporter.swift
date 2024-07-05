import Foundation
import os.log

import Background

public enum ReporterError: Error {
    case failedToCreateURL
}

public actor WellsReporter {
	public typealias ReportLocationProvider = @Sendable (String) -> URL?
	public typealias ExistingLogHandler = @Sendable (URL, Date) -> Void

    public static let shared = WellsReporter()
    public static let uploadFileExtension = "wellsdata"
    private static let maximumAccountCount = 5
    private static let maximumLogAge: TimeInterval = 2.0 * 24.0 * 60.0 * 60.0
	public static let defaultRetryInterval = 5 * 60.0

	public private(set) var existingLogHandler: ExistingLogHandler = { _, _ in }

	public nonisolated let baseURL: URL
    private let logger = OSLog(subsystem: "com.chimehq.Wells", category: "Reporter")
	private let uploader: Uploader
	private let backgroundIdentifier: String?
    public private(set) var locationProvider: ReportLocationProvider

	public static nonisolated let defaultBackgroundIdentifier: String = {
		let bundleId = Bundle.main.bundleIdentifier ?? "com.chimehq.Wells"

		return bundleId + ".Uploader"
	}()

	public init(
		baseURL: URL = defaultDirectory,
		backgroundIdentifier: String? = WellsReporter.defaultBackgroundIdentifier,
		locationProvider: @escaping ReportLocationProvider
	) {
        self.baseURL = baseURL
		self.backgroundIdentifier = backgroundIdentifier
		self.locationProvider = {
			baseURL.appendingPathComponent($0).appendingPathExtension(WellsReporter.uploadFileExtension)
		}

		let config: URLSessionConfiguration

		if let identifier = backgroundIdentifier {
			config = URLSessionConfiguration.background(withIdentifier: identifier)
		} else {
			config = URLSessionConfiguration.default
		}

		self.uploader = Uploader(
			sessionConfiguration: config,
			identifierProvider: { $0.originalRequest?.uploadIdentifier }
		)

		Task {
			try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)

			await handleExistingLogs()
		}
    }

	public init(
		baseURL: URL = defaultDirectory,
		backgroundIdentifier: String? = WellsReporter.defaultBackgroundIdentifier
	) {
		let provider: ReportLocationProvider = {
			baseURL.appendingPathComponent($0).appendingPathExtension(WellsReporter.uploadFileExtension)
		}

		self.init(baseURL: baseURL, backgroundIdentifier: backgroundIdentifier, locationProvider: provider)
	}

    public var usingBackgroundUploads: Bool {
        return backgroundIdentifier != nil
    }

    private func defaultURL(for identifier: String) -> URL {
        return baseURL.appendingPathComponent(identifier).appendingPathExtension(WellsReporter.uploadFileExtension)
    }

	public func setLocationProvider(_ value: @escaping ReportLocationProvider) {
		self.locationProvider = value
	}

	public func setExistingLogHandler(_ value: @escaping ExistingLogHandler) {
		self.existingLogHandler = value
	}

    private func reportURL(for identifier: String) -> URL? {
		locationProvider(identifier)
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

		Task<Void, Never> {
            await uploader.beginUpload(of: fileURL, with: request, identifier: identifier, handler: { _, result in
				Task<Void, Never> {
					await self.handleUploadComplete(result, for: identifier, request: uploadRequest)
				}
			})
		}
    }

	private func handleUploadComplete(_ result: Result<URLResponse, Error>, for identifier: String, request: URLRequest) {
		let networkResponse = NetworkResponse<Void>(with: result)

		switch networkResponse {
		case .rejected:
			os_log("Server rejected report submission: %{public}@", log: self.logger, type: .error, identifier)

			removeFile(with: identifier)
		case let .failed(error):
			os_log("Failed to submit report: %{public}@ - %{public}@", log: self.logger, type: .error, identifier, String(describing: error))

			removeFile(with: identifier)
		case let .retry(response):
			let interval = response.retryAfterInterval ?? Self.defaultRetryInterval

			retrySubmission(of: identifier, after: interval, with: request)
		case .success:
			os_log("Submitted report successfully: %{public}@", log: self.logger, type: .error, identifier)

			removeFile(with: identifier)
		}
	}

    public func createReportDirectoryIfNeeded() throws {
        if FileManager.default.directoryExists(at: baseURL) {
            return
        }

        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
    }

    func handleExistingLogs() {
		let urls = try? FileManager.default.contentsOfDirectory(
			at: baseURL,
			includingPropertiesForKeys: [.creationDateKey]
		)

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

    private func removeFile(with identifier: String) {
        guard let fileURL = reportURL(for: identifier) else {
            os_log("Failed to compute URL for %{public}@", log: self.logger, type: .error, identifier)

            return
        }

        removeFile(at: fileURL)
    }

    private func retrySubmission(of identifier: String, after interval: TimeInterval, with request: URLRequest) {
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

		Task {
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

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
