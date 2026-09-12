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
    dependencies: [
        .package(
            url: "https://github.com/ghostflyby/librime-xcframework.git",
            exact: "1.16.1-pack.8"
        )
    ],
    targets: [
        .target(
            name: "RimeKitBridge",
            dependencies: [
                .product(name: "RimeStatic", package: "librime-xcframework")
            ],
            path: "Sources/RimeKitBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),
        .target(
            name: "PinyinCore",
            dependencies: ["RimeKitBridge"],
            path: "Sources/PinyinCore",
            resources: [
                .copy("Resources/Rime")
            ]
        ),
        .testTarget(
            name: "PinyinCoreTests",
            dependencies: ["PinyinCore"],
            path: "Tests/PinyinCoreTests"
        )
    ]
)
