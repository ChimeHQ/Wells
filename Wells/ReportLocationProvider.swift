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

struct DefaultReportLocationProvider: ReportLocationProvider {
    public static let uploadFileExtension = "wellsdata"

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func reportURL(for identifier: String) -> URL? {
        let fileExtension = DefaultReportLocationProvider.uploadFileExtension

        return baseURL.appendingPathComponent(identifier).appendingPathExtension(fileExtension)
    }
}
