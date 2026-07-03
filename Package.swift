// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PLOSKernel",
    platforms: [.macOS(.v13), .iOS(.v16)],
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
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
