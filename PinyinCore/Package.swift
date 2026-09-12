// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PinyinCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PinyinCore",
            targets: ["PinyinCore"]
        )
    ],
    targets: [
        .target(
            name: "PinyinCore",
            path: "Sources/PinyinCore"
        ),
        .testTarget(
            name: "PinyinCoreTests",
            dependencies: ["PinyinCore"],
            path: "Tests/PinyinCoreTests"
        )
    ]
)
