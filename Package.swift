// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ISBN",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [.library(name: "ISBN", targets: ["ISBN"])],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder", from: "0.17.0")
    ],
    targets: [
        .target(
            name: "ISBN",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "ISBNRegistrationGroupsUpdater",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "XMLCoder", package: "XMLCoder")
            ],
            path: "Sources/ISBNRegistrationGroupsUpdater",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ISBNTests",
            dependencies: ["ISBN"],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("StrictConcurrency=complete")
]
