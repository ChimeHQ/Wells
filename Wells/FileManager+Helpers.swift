//
//  FileManager+ScopedURLs.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-09.
//

import Foundation

extension FileManager {
    func bundleIdScopedURL(for dir: FileManager.SearchPathDirectory, bundleId: String) -> URL? {
        guard let url = FileManager.default.urls(for: dir, in: .userDomainMask).first else {
            return nil
        }

        let scopedURL = url.appendingPathComponent(bundleId)

        try? FileManager.default.createDirectory(at: scopedURL, withIntermediateDirectories: true, attributes: nil)

        return scopedURL
    }

    func bundleIdScopedURL(for dir: FileManager.SearchPathDirectory) -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }

        return bundleIdScopedURL(for: dir, bundleId: bundleId)
    }
}

extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }

        return isDir.boolValue
    }
}
