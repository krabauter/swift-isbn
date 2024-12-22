// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ISBN",
    products: [
        .library(name: "ISBN", targets: ["ISBN"])
    ],
    targets: [
        .target(
            name: "ISBN",
            swiftSettings: [.swiftLanguageMode(.v6), .enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        .testTarget(
            name: "ISBNTests",
            dependencies: ["ISBN"]
        )
    ]
)
