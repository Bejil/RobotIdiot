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
        .target(
            name: "RobotIdiotCore",
            resources: [
                .copy("Resources/robot_idiot_100_levels_v6.json")
            ]
        ),
        .testTarget(
            name: "RobotIdiotCoreTests",
            dependencies: ["RobotIdiotCore"]
        )
    ]
)
