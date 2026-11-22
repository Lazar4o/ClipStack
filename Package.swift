// swift-tools-version: 5.10
// Keep 5.10. Tools-version 6.x switches to Swift 6 language mode (strict-concurrency errors).
import PackageDescription

let package = Package(
    name: "ClipStack",
    platforms: [.macOS("26.0")],                 // string form works with tools-version 5.10
    products: [.executable(name: "ClipStack", targets: ["ClipStack"])],
    targets: [
        .target(name: "ClipStackCore", path: "Sources/ClipStackCore"),
        .executableTarget(name: "ClipStack", dependencies: ["ClipStackCore"], path: "Sources/ClipStack"),
        .testTarget(name: "ClipStackCoreTests", dependencies: ["ClipStackCore"], path: "Tests/ClipStackCoreTests"),
    ]
)
