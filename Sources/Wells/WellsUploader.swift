import Foundation
import os.log

public protocol WellsUploaderDelegate: AnyObject {
    func finishedUpload(of identifier: WellsUploader.Identifier, with error: NetworkResponseError?, by uploader: WellsUploader)
    func uploadIdentifier(for request: URLRequest, with uploader: WellsUploader) -> WellsUploader.Identifier?
}

public class WellsUploader: NSObject {
    private static let defaultRetryInterval: TimeInterval = 1 * 60.0

    public typealias Identifier = String
    private let queue: OperationQueue
    private let logger: OSLog
    public let backgroundIdentifier: String?

    public weak var delegate: WellsUploaderDelegate?

    public static var defaultBackgroundIdentifier: String = {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.chimehq.Wells"

        return bundleId + ".Uploader"
    }()

    private lazy var sessionConfiguation: URLSessionConfiguration = {
        guard let identifier = backgroundIdentifier else {
            return URLSessionConfiguration.default
        }

        let config = URLSessionConfiguration.background(withIdentifier: identifier)

        config.isDiscretionary = true

        // this API was marked as unaviable in earlier SDK versions
        #if compiler(>=5.3)
        if #available(macOS 11.0, *) {
            config.sessionSendsLaunchEvents = false
        }
        #endif

        return config
    }()

    private lazy var session: URLSession = {
        let config = sessionConfiguation

        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()

    public init(backgroundIdentifier: String? = defaultBackgroundIdentifier) {
        self.backgroundIdentifier = backgroundIdentifier
        self.logger = OSLog(subsystem: "com.chimehq.Wells", category: "Uploader")

        self.queue = OperationQueue()

        queue.maxConcurrentOperationCount = 1
        queue.name = "com.chimehq.Wells.Uploader"

        super.init()
    }

    public func uploadFile(_ fileURL: URL, using request: URLRequest) {
        guard let identifier = uploadIdentifier(for: request) else {
            os_log("Unable to determine identifier %{public}@", log: logger, type: .info, fileURL.path)
            return
        }

        getUploadTasks { (uploadTasks) in
            if uploadTasks.contains(where: { self.uploadIdentifier(from: $0) == identifier }) {
                os_log("Preexisting upload found for: %{public}@", log: self.logger, type: .info, identifier)

                return
            }

            OperationQueue.main.addOperation {
                self.beginUploadTask(with: fileURL, identifier: identifier, using: request)
            }
        }
    }

    private func uploadIdentifier(for request: URLRequest) -> Identifier? {
        return delegate?.uploadIdentifier(for: request, with: self)
    }

    private func uploadIdentifier(from task: URLSessionTask) -> Identifier? {
        guard let request = task.originalRequest else { return nil }

        return uploadIdentifier(for: request)
    }

    private func getUploadTasks(completionHandler: @escaping ([URLSessionUploadTask]) -> Void) {
        OperationQueue.main.addOperation {
            self.session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
                completionHandler(uploadTasks)
            }
        }
    }

    private func beginUploadTask(with fileURL: URL, identifier: Identifier, using request: URLRequest) {
        os_log("Submitting %{public}@: %{public}@", log: logger, type: .info, identifier, fileURL.path)

        if FileManager.default.isReadableFile(atPath: fileURL.path) == false {
            os_log("unable to read file at path %{public}@", log: logger, type: .error, fileURL.path)
            return
        }

        let task = session.uploadTask(with: request, fromFile: fileURL)

        task.taskDescription = "Wells Upload: \(identifier)"

        task.resume()
    }

    private func retryInterval(for task: URLSessionTask) -> TimeInterval {
        guard let response = task.response else {
            return WellsUploader.defaultRetryInterval
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return WellsUploader.defaultRetryInterval
        }

        if let retryAfter = httpResponse.retryAfterInterval {
            return retryAfter
        }

        // This optional fallback shouldn't occur, but if it does
        // make it large
        let attempt = task.originalRequest?.attemptCount ?? 5

        return TimeInterval(attempt + 1) * WellsUploader.defaultRetryInterval
    }
}

extension WellsUploader: URLSessionDelegate {
}

extension WellsUploader: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let identifier = uploadIdentifier(from: task) else {
            os_log("failed to recover identifier from task %{public}@", log: logger, type: .error, String(describing: error))
            return
        }

        let response = NetworkResponse(task: task, error: error)

        OperationQueue.main.addOperation {
            switch response {
            case .success:
                self.delegate?.finishedUpload(of: identifier, with: nil, by: self)
            case .failed(let e):
                self.delegate?.finishedUpload(of: identifier, with: e, by: self)
            case .rejected:
                self.delegate?.finishedUpload(of: identifier, with: .requestInvalid, by: self)
            case .retry:
                let networkError: NetworkResponseError

                if let request = task.originalRequest {
                    let interval = self.retryInterval(for: task)

                    networkError = .transientFailure(interval, request)
                } else {
                    networkError = .missingOriginalRequest
                }

                self.delegate?.finishedUpload(of: identifier, with: networkError, by: self)
            }
        }
    }
}
