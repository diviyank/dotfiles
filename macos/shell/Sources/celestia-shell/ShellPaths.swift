import Foundation

enum ShellPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let colors = home.appendingPathComponent(".local/state/celestia/colors.json")
    static let settings = home.appendingPathComponent(".config/celestia/shell.json")
    static let applyYabai = home.appendingPathComponent(".config/wm/apply-yabai.sh")
    static let yabai = "/opt/homebrew/bin/yabai"
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
