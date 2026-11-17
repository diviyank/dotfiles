import Foundation

public enum LauncherMode: Equatable {
    case apps(String), actions(String), calculator(String), schemes(String), variants(String), wallpapers(String)
}

public struct LauncherAction: Equatable {
    public let name: String
    public let title: String
    public let subtitle: String
    public let takesQuery: Bool
}

public let launcherActions = [
    LauncherAction(name: "calc", title: "Calculator", subtitle: "Do simple maths", takesQuery: true),
    LauncherAction(name: "scheme", title: "Scheme", subtitle: "Change the colour scheme", takesQuery: true),
    LauncherAction(name: "variant", title: "Variant", subtitle: "Change the scheme variant", takesQuery: true),
    LauncherAction(name: "wallpaper", title: "Wallpaper", subtitle: "Change the wallpaper", takesQuery: true),
    LauncherAction(name: "random", title: "Random", subtitle: "Switch to a random wallpaper", takesQuery: false),
    LauncherAction(name: "light", title: "Light", subtitle: "Use the light colour scheme", takesQuery: false),
    LauncherAction(name: "dark", title: "Dark", subtitle: "Use the dark colour scheme", takesQuery: false),
    LauncherAction(name: "lock", title: "Lock", subtitle: "Lock the screen", takesQuery: false),
    LauncherAction(name: "sleep", title: "Sleep", subtitle: "Put the Mac to sleep", takesQuery: false),
    LauncherAction(name: "logout", title: "Log out", subtitle: "Log out of this session", takesQuery: false),
    LauncherAction(name: "restart", title: "Restart", subtitle: "Restart the Mac", takesQuery: false),
    LauncherAction(name: "shutdown", title: "Shut down", subtitle: "Shut down the Mac", takesQuery: false),
]

public func filterActions(_ query: String) -> [LauncherAction] {
    guard !query.isEmpty else { return launcherActions }
    let scored = launcherActions.enumerated().compactMap { index, action in
        fuzzyScore(query, action.name).map { (index, action, $0) }
    }
    return scored.sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }.map(\.1)
}

private let queryModes: [(String, (String) -> LauncherMode)] = [
    ("calc", LauncherMode.calculator), ("scheme", LauncherMode.schemes),
    ("variant", LauncherMode.variants), ("wallpaper", LauncherMode.wallpapers),
]

public func parseMode(_ text: String) -> LauncherMode {
    guard text.hasPrefix(">") else { return .apps(text) }
    let rest = String(text.dropFirst())
    for (name, mode) in queryModes where rest == name || rest.hasPrefix(name + " ") {
        return mode(rest.dropFirst(name.count).trimmingCharacters(in: .whitespaces))
    }
    return .actions(rest)
}
