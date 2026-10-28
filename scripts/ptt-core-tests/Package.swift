// swift-tools-version:6.0
// Builds Chorus/PTT/Core on its own and runs ChorusTests/PTT with XCTest
// (XCTest needs Xcode; `swift build` alone works with Command Line Tools): `swift test --package-path scripts/ptt-core-tests`.
// The module is named Chorus so the tests' `@testable import Chorus` works
// both here and in the Xcode test target.
import PackageDescription

let package = Package(
    name: "PTTCoreTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Chorus", path: "Sources/Chorus"),
        .testTarget(name: "PTTCoreTests", dependencies: ["Chorus"], path: "Tests/PTTCoreTests"),
    ]
)
