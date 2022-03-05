// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Wells",
    platforms: [.macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "Wells", targets: ["Wells"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Wells", dependencies: []),
    ]
)
