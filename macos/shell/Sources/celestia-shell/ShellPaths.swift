import Foundation
import LauncherCore

enum ShellPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let colors = home.appendingPathComponent(".local/state/celestia/colors.json")
    static let weather = home.appendingPathComponent(".local/state/celestia/weather.json")
    static let settings = home.appendingPathComponent(".config/celestia/shell.json")
    static let applyYabai = home.appendingPathComponent(".config/wm/apply-yabai.sh")
    static let yabai = "/opt/homebrew/bin/yabai"
    static let notifications = home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
    static let notificationsWAL = home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db-wal")
    static let scheme = home.appendingPathComponent(".local/state/celestia/scheme.json")
    static let wallpaperSource = home.appendingPathComponent(".local/state/celestia/source.jpg")
    static let currentWallpaper = home.appendingPathComponent(".local/state/celestia/wallpaper")
    static let wallpapers = home.appendingPathComponent("Pictures/Wallpapers", isDirectory: true)
    static var wallpaperFolders: [URL] {
        [wallpapers] + appleWallpaperFolders(
            desktopPictures: URL(fileURLWithPath: "/System/Library/Desktop Pictures", isDirectory: true),
            assets: URL(fileURLWithPath: "/System/Library/AssetsV2/com_apple_MobileAsset_DesktopPicture", isDirectory: true)
        )
    }
    static let thumbnails = home.appendingPathComponent(".cache/celestia/thumbs", isDirectory: true)
    static let wallpaperScript = home.appendingPathComponent(".local/bin/celestia-wallpaper")
    static let matugen = [home.appendingPathComponent(".cargo/bin/matugen").path, "/opt/homebrew/bin/matugen"]
        .first { FileManager.default.isExecutableFile(atPath: $0) }
}

func runProcess(_ path: String, _ arguments: [String]) -> Data? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return process.terminationStatus == 0 ? data : nil
}

func shellLog(_ message: String) {
    FileHandle.standardError.write(Data("celestia-shell: \(message)\n".utf8))
}
