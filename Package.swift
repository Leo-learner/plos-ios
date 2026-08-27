// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PLOS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PLOSKernel", targets: ["PLOSKernel"]),
    ],
    targets: [
        .target(
            name: "PLOSKernel",
            dependencies: [],
            path: "Sources/PLOSKernel"
        ),
        .testTarget(
            name: "PLOSKernelTests",
            dependencies: ["PLOSKernel"],
            path: "Tests/PLOSKernelTests",
            resources: [.copy("Fixtures")]
        ),
        // App sources as a SwiftPM library so the app's data loop is testable headlessly
        // (and cross-typecheckable for iOS without Xcode — see ACCEPTANCE.md "影子构建").
        .target(
            name: "PLOSAppCheck",
            dependencies: ["PLOSKernel"],
            path: "PLOS"
        ),
        .testTarget(
            name: "PLOSAppTests",
            dependencies: ["PLOSAppCheck", "PLOSKernel"],
            path: "Tests/PLOSAppTests"
        ),
    ]
)
