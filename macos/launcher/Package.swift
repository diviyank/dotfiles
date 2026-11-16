// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "celestia-launcher",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LauncherCore", targets: ["LauncherCore"]),
        .executable(name: "celestia-launcher", targets: ["celestia-launcher"]),
    ],
    targets: [
        .target(name: "LauncherCore"),
        .executableTarget(name: "celestia-launcher", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
    ]
)
