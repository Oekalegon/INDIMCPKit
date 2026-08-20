// swift-tools-version: 6.1
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
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "INDIMCPKit",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .executableTarget(
            name: "INDIMCPKitTestApp",
            dependencies: ["INDIMCPKit"]
        ),
        .testTarget(
            name: "INDIMCPKitTests",
            dependencies: [
                "INDIMCPKit",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
