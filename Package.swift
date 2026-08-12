// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "INDIMCPKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "INDIMCPKit", targets: ["INDIMCPKit"]),
    ],
    targets: [
        .target(
            name: "INDIMCPKit"
        ),
        .executableTarget(
            name: "INDIMCPKitTestApp",
            dependencies: ["INDIMCPKit"]
        ),
        .testTarget(
            name: "INDIMCPKitTests",
            dependencies: ["INDIMCPKit"]
        ),
    ]
)
