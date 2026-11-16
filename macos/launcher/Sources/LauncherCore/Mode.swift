import Foundation

public enum LauncherMode: Equatable {
    case apps(String), commands(String), wallpapers(String)
}

public let launcherCommands = ["wallpaper"]

public func parseMode(_ text: String) -> LauncherMode {
    guard text.hasPrefix(">") else { return .apps(text) }
    let rest = String(text.dropFirst())
    let command = "wallpaper"
    if rest == command || rest.hasPrefix(command + " ") {
        let query = rest.dropFirst(command.count).trimmingCharacters(in: .whitespaces)
        return .wallpapers(query)
    }
    return .commands(rest)
}
