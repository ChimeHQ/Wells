// swift-tools-version: 5.8

import PackageDescription

let package = Package(
	name: "Wells",
	platforms: [
		.macOS(.v11),
		.iOS(.v14),
		.tvOS(.v14),
		.watchOS(.v7),
		.macCatalyst(.v14),
	],
	products: [
		.library(name: "Wells", targets: ["Wells"]),
	],
	dependencies: [
		.package(url: "https://github.com/ChimeHQ/Background", revision: "11f1bc95a7ec88c275b522b12883ada9dbc062e6")
	],
	targets: [
		.target(name: "Wells", dependencies: ["Background"]),
		.testTarget(name: "WellsTests", dependencies: ["Wells"]),
	]
)

let swiftSettings: [SwiftSetting] = [
	.enableExperimentalFeature("StrictConcurrency")
]

for target in package.targets {
	var settings = target.swiftSettings ?? []
	settings.append(contentsOf: swiftSettings)
	target.swiftSettings = settings
}
