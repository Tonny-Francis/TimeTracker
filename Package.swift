// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TimeTracker",
            targets: ["TimeTracker"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TimeTracker",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
