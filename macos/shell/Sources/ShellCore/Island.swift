import Foundation

public enum IslandMetrics {
    public static let wing: CGFloat = 140
    public static let toastWing: CGFloat = 320
}

public func notchRect(left: CGRect?, right: CGRect?) -> CGRect? {
    guard let left, let right, right.minX > left.maxX else { return nil }
    return CGRect(x: left.maxX, y: left.minY, width: right.minX - left.maxX, height: left.height)
}

private func clampedHorizontally(_ rect: CGRect, in screen: CGRect) -> CGRect {
    let width = min(rect.width, screen.width)
    let x = min(max(rect.minX, screen.minX), screen.maxX - width)
    return CGRect(x: x, y: rect.minY, width: width, height: rect.height)
}

public func islandIdleFrame(notch: CGRect, screen: CGRect) -> CGRect {
    clampedHorizontally(notch.insetBy(dx: -IslandMetrics.wing, dy: 0), in: screen)
}

public func islandToastFrame(notch: CGRect, screen: CGRect) -> CGRect {
    clampedHorizontally(notch.insetBy(dx: -IslandMetrics.toastWing, dy: 0), in: screen)
}

public struct MeetingSlot: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

private let meetingLookahead: TimeInterval = 30 * 60
private let meetingNowWindow: TimeInterval = 5 * 60

public func meetingText(_ slots: [MeetingSlot], now: Date) -> String? {
    let started = slots.contains { $0.start <= now && now < min($0.end, $0.start.addingTimeInterval(meetingNowWindow)) }
    if started { return "Meeting now" }
    let upcoming = slots.map(\.start).filter { $0 > now && $0.timeIntervalSince(now) <= meetingLookahead }.min()
    guard let upcoming else { return nil }
    return "Meeting in \(max(1, Int((upcoming.timeIntervalSince(now) / 60).rounded(.up)))) min"
}

public struct IslandNotice: Equatable, Sendable {
    public let id: Int64
    public let app: String
    public let title: String
    public let detail: String?
    public let body: String
    public let link: URL?

    public init(id: Int64, app: String, title: String, detail: String?, body: String, link: URL?) {
        self.id = id
        self.app = app
        self.title = title
        self.detail = detail
        self.body = body
        self.link = link
    }
}

private func singleLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
}

public func parseNotificationRecord(_ data: Data, id: Int64, app: String) -> IslandNotice? {
    if app.lowercased() == discordBundleID {
        guard let note = parseDiscordRecord(data) else { return nil }
        return IslandNotice(id: id, app: app, title: note.sender, detail: note.place, body: note.body, link: note.link)
    }
    guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let request = plist["req"] as? [String: Any]
    else { return nil }
    let title = singleLine(request["titl"] as? String ?? "")
    let subtitle = singleLine(request["subt"] as? String ?? "")
    let body = singleLine(request["body"] as? String ?? "")
    guard !title.isEmpty || !body.isEmpty else { return nil }
    return IslandNotice(id: id, app: app, title: title, detail: subtitle.isEmpty ? nil : subtitle, body: body, link: nil)
}

private let ignoredNotificationApps: Set<String> = ["com.apple.scripteditor2", "local.celestia.shell"]

public func isIgnoredNotificationApp(_ identifier: String) -> Bool {
    ignoredNotificationApps.contains(identifier.lowercased()) || identifier.hasPrefix("_system_center_:")
}

public struct FeedCursor: Sendable {
    public private(set) var last: Int64?
    private static let freshness: TimeInterval = 30

    public init() {}

    public mutating func accept(_ rows: [(id: Int64, delivered: Date)], now: Date) -> [Int64] {
        guard let newest = rows.map(\.id).max() else { return [] }
        guard let last, newest >= last else {
            self.last = newest
            return []
        }
        self.last = newest
        return rows
            .filter { $0.id > last && now.timeIntervalSince($0.delivered) <= Self.freshness }
            .map(\.id)
            .sorted()
    }
}

public enum IslandEvent: Equatable, Sendable {
    case notice(IslandNotice)
    case nowPlaying(SpotifyTrack)

    var isNowPlaying: Bool {
        if case .nowPlaying = self { return true }
        return false
    }
}

public struct IslandQueue: Sendable {
    private var events: [IslandEvent] = []

    public init() {}

    public var isEmpty: Bool { events.isEmpty }

    public mutating func push(_ event: IslandEvent) {
        if event.isNowPlaying { events.removeAll(where: \.isNowPlaying) }
        events.append(event)
    }

    public mutating func pop() -> IslandEvent? {
        events.isEmpty ? nil : events.removeFirst()
    }
}

public func shouldAnnounce(previous: SpotifyTrack?, current: SpotifyTrack?) -> Bool {
    guard let current, current.isPlaying else { return false }
    guard let previous else { return true }
    return previous.id != current.id || !previous.isPlaying
}
