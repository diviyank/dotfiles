// swift-tools-version:5.9
import Foundation
import PackageDescription

let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Info.plist").path

let package = Package(
    name: "celestia-shell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "celestia-shell", targets: ["celestia-shell"]),
    ],
    targets: [
        .target(name: "LauncherCore"),
        .target(name: "ShellCore"),
        .executableTarget(
            name: "celestia-shell",
            dependencies: ["LauncherCore", "ShellCore"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist])]
        ),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "ShellCoreTests", dependencies: ["ShellCore"]),
    ]
)
