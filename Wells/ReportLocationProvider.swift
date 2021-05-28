//
//  ReportLocationProvider.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-11.
//

import Foundation

public protocol ReportLocationProvider {
    func reportURL(for identifier: String) -> URL?
}

public struct IdentifierExtensionLocationProvider: ReportLocationProvider {
    public var baseURL: URL
    public var fileExtension: String

    public init(baseURL: URL, fileExtension: String) {
        self.baseURL = baseURL
        self.fileExtension = fileExtension
    }

    public func reportURL(for identifier: String) -> URL? {
        return baseURL.appendingPathComponent(identifier).appendingPathExtension(fileExtension)
    }
}

public struct FilenameIdentifierLocationProvider: ReportLocationProvider {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func reportURL(for identifier: String) -> URL? {
        return baseURL.appendingPathComponent(identifier)
    }
}
