// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MCGui",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MCGuiCore", targets: ["MCGuiCore"]),
        .library(name: "MCGuiUI", targets: ["MCGuiUI"]),
        .library(name: "MCGuiMacOS", targets: ["MCGuiMacOS"]),
        .executable(name: "MCGuiApp", targets: ["MCGuiApp"])
    ],
    targets: [
        .target(
            name: "MCGuiCore",
            dependencies: []
        ),
        .target(
            name: "MCGuiUI",
            dependencies: ["MCGuiCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MCGuiMacOS",
            dependencies: ["MCGuiCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "MCGuiApp",
            dependencies: ["MCGuiUI", "MCGuiMacOS"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MCGuiCoreTests",
            dependencies: ["MCGuiCore"]
        ),
        .testTarget(
            name: "MCGuiUITests",
            dependencies: ["MCGuiUI"]
        ),
        .testTarget(
            name: "MCGuiMacOSTests",
            dependencies: ["MCGuiMacOS"]
        )
    ]
)
