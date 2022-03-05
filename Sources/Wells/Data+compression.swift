//
//  Data+compression.swift
//  Wells
//
//  Created by Matt Massicotte on 2020-02-14.
//

import Foundation
import zlib

public extension Data {
    func writeGZCompressedData(to url: URL) throws {
        let file = url.path.withCString { (pathPtr) in
            "w".withCString { (modePtr) -> gzFile in
                return gzopen(pathPtr, modePtr)
            }
        }

        let success = withUnsafeBytes { (buffer) -> Bool in
            let size = buffer.count
            let result = gzwrite(file, buffer.baseAddress, UInt32(size))

            return result == size
        }

        gzclose(file)

        if !success {
            throw NSError(domain: "libz compression failure", code: 0, userInfo: nil)
        }
    }
}
