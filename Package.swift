// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DoNow",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DoNow", targets: ["DoNow"])
    ],
    targets: [
        .executableTarget(
            name: "DoNow",
            path: "Sources/DoNow"
        ),
        .testTarget(
            name: "DoNowTests",
            dependencies: ["DoNow"],
            path: "Tests/DoNowTests"
        )
    ]
)
