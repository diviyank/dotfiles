// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "celestia-shell",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "celestia-shell", targets: ["celestia-shell"]),
    ],
    targets: [
        .target(name: "LauncherCore"),
        .target(name: "ShellCore"),
        .executableTarget(name: "celestia-shell", dependencies: ["LauncherCore", "ShellCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"]),
    ]
)
