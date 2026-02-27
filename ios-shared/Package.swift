// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenbaseShared",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "OpenbaseShared",
            targets: ["OpenbaseShared"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2"),
    ],
    targets: [
        .target(
            name: "OpenbaseShared",
            dependencies: ["SwiftyJSON"]
        ),
        .testTarget(
            name: "OpenbaseSharedTests",
            dependencies: ["OpenbaseShared"]
        ),
    ]
)
