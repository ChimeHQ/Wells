//
//  WellsUploader.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-02.
//

import Foundation
import os.log

public protocol WellsUploaderDelegate: AnyObject {
    func finishedUpload(of identifier: WellsUploader.Identifier, with error: Error?, by uploader: WellsUploader)
    func uploadIdentifier(for request: URLRequest, with uploader: WellsUploader) -> WellsUploader.Identifier?
}

public class WellsUploader: NSObject {
    public typealias Identifier = String
    private let queue: OperationQueue
    private let logger: OSLog
    public let backgroundIdentifier: String

    public weak var delegate: WellsUploaderDelegate?

    public static var defaultBackgroundIdentifier: String = {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.chimehq.Wells"

        return bundleId + ".WellsUploader"
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundIdentifier)
        config.isDiscretionary = true

        return URLSession(configuration: config, delegate: self, delegateQueue: self.queue)
    }()

    public init(backgroundIdentifier: String = defaultBackgroundIdentifier) {
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
        os_log("Submitting %{pubilc}@: %{public}@", log: logger, type: .info, identifier, fileURL.path)

        if FileManager.default.isReadableFile(atPath: fileURL.path) == false {
            os_log("unable to read file at path %{public}@", log: logger, type: .error, fileURL.path)
            return
        }

        let task = session.uploadTask(with: request, fromFile: fileURL)

        task.taskDescription = "Wells Upload: \(identifier)"

        task.resume()
    }

    private func retryTask(_ task: URLSessionTask) {
        os_log("upload retry not implemented", log: logger, type: .error)
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
                self.delegate?.finishedUpload(of: identifier, with: NetworkResponseError.requestInvalid, by: self)
            case .retry:
                self.retryTask(task)
            }
        }
    }
}
