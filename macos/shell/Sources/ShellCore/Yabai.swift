import Foundation

public struct BarWindow: Equatable, Sendable {
    public let id: Int
    public let pid: Int32
    public let app: String
    public let title: String
    public let hasFocus: Bool
}

public struct BarSpace: Equatable, Sendable {
    public let number: Int
    public let label: String
    public let isVisible: Bool
    public let windows: [BarWindow]
}

public struct BarDisplay: Equatable, Sendable {
    public let index: Int
    public let uuid: String
    public let spaces: [BarSpace]
    public let isFullscreen: Bool
}

private let spaceLabels = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

public func spaceNumber(label: String) -> Int? {
    spaceLabels.firstIndex(of: label).map { $0 + 1 }
}

private struct YabaiDisplay: Decodable {
    let index: Int
    let uuid: String
}

private struct YabaiSpace: Decodable {
    let index: Int
    let label: String
    let display: Int
    let windows: [Int]
    let isVisible: Bool
    let isNativeFullscreen: Bool

    enum CodingKeys: String, CodingKey {
        case index, label, display, windows
        case isVisible = "is-visible"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}

private struct YabaiWindow: Decodable {
    let id: Int
    let pid: Int32
    let app: String
    let title: String
    let hasFocus: Bool
    let isMinimized: Bool
    let isHidden: Bool
    let scratchpad: String

    enum CodingKeys: String, CodingKey {
        case id, pid, app, title, scratchpad
        case hasFocus = "has-focus"
        case isMinimized = "is-minimized"
        case isHidden = "is-hidden"
    }

    var isShown: Bool { !isMinimized && !isHidden && scratchpad.isEmpty }
}

public func decodeBarDisplays(displays: Data, spaces: Data, windows: Data) -> [BarDisplay]? {
    let decoder = JSONDecoder()
    guard let yabaiDisplays = try? decoder.decode([YabaiDisplay].self, from: displays),
          let yabaiSpaces = try? decoder.decode([YabaiSpace].self, from: spaces),
          let yabaiWindows = try? decoder.decode([YabaiWindow].self, from: windows)
    else { return nil }

    let windowsById = Dictionary(
        yabaiWindows.filter(\.isShown).map { ($0.id, BarWindow(id: $0.id, pid: $0.pid, app: $0.app, title: $0.title, hasFocus: $0.hasFocus)) },
        uniquingKeysWith: { first, _ in first }
    )

    return yabaiDisplays.sorted { $0.index < $1.index }.map { display in
        let onDisplay = yabaiSpaces.filter { $0.display == display.index }
        let barSpaces = onDisplay.compactMap { space -> BarSpace? in
            guard let number = spaceNumber(label: space.label) else { return nil }
            return BarSpace(number: number, label: space.label, isVisible: space.isVisible,
                            windows: space.windows.compactMap { windowsById[$0] })
        }
        return BarDisplay(
            index: display.index,
            uuid: display.uuid,
            spaces: barSpaces.sorted { $0.number < $1.number },
            isFullscreen: onDisplay.contains { $0.isVisible && $0.isNativeFullscreen }
        )
    }
}

public func focusedWindow(_ displays: [BarDisplay]) -> BarWindow? {
    displays.lazy.flatMap(\.spaces).flatMap(\.windows).first(where: \.hasFocus)
}
