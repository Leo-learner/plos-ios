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
    ]
)
