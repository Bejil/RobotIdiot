// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RobotIdiotCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RobotIdiotCore", targets: ["RobotIdiotCore"])
    ],
    targets: [
        .target(name: "RobotIdiotCore"),
        .testTarget(
            name: "RobotIdiotCoreTests",
            dependencies: ["RobotIdiotCore"]
        )
    ]
)
