//
//  FileManager+ScopedURLs.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-10-09.
//

import Foundation

extension FileManager {
    func subdirectoryURL(named name: String, in dir: FileManager.SearchPathDirectory) -> URL? {
        guard let url = FileManager.default.urls(for: dir, in: .userDomainMask).first else {
            return nil
        }

        let scopedURL = url.appendingPathComponent(name)

        try? FileManager.default.createDirectory(at: scopedURL, withIntermediateDirectories: true, attributes: nil)

        return scopedURL
    }

    func bundleIdSubdirectoryURL(for dir: FileManager.SearchPathDirectory) -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }

        return subdirectoryURL(named: bundleId, in: dir)
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
