// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ISBN",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [.library(name: "ISBN", targets: ["ISBN"])],
    targets: [
        .target(name: "ISBN"),
        .target(name: "ISBNRangeMessage"),
        .executableTarget(
            name: "ISBNRegistrationGroupsUpdater",
            dependencies: ["ISBNRangeMessage"]
        ),
        .testTarget(
            name: "ISBNTests",
            dependencies: ["ISBN"]
        ),
        .testTarget(
            name: "ISBNRangeMessageTests",
            dependencies: ["ISBN", "ISBNRangeMessage"],
            exclude: ["Fixtures"]
        )
    ]
)
