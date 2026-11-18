import Foundation
import ShellCore
import Testing

private let left = CGRect(x: 1920, y: 1039, width: 751, height: 38)
private let right = CGRect(x: 2880, y: 1039, width: 750, height: 38)
private let screen = CGRect(x: 1920, y: -35, width: 1710, height: 1112)
private let notch = CGRect(x: 2671, y: 1039, width: 209, height: 38)

@Test func notchSitsBetweenAuxiliaryAreas() {
    #expect(notchRect(left: left, right: right) == notch)
    #expect(notchRect(left: nil, right: right) == nil)
    #expect(notchRect(left: left, right: nil) == nil)
}

@Test func idleFrameAddsWingsAndClamps() {
    let frame = islandIdleFrame(notch: notch, screen: screen)
    #expect(frame == CGRect(x: notch.minX - IslandMetrics.wing, y: notch.minY, width: notch.width + 2 * IslandMetrics.wing, height: 38))
    let narrow = CGRect(x: 2700, y: -35, width: 150, height: 1112)
    #expect(islandIdleFrame(notch: notch, screen: narrow).minX >= narrow.minX)
    #expect(islandIdleFrame(notch: notch, screen: narrow).maxX <= narrow.maxX)
}

@Test func toastHangsFromTheTopEdge() {
    let frame = islandToastFrame(notch: notch, screen: screen)
    #expect(frame.maxY == notch.maxY)
    #expect(frame.height == IslandMetrics.toastHeight)
    #expect(frame.width == IslandMetrics.toastWidth)
    #expect(frame.midX == notch.midX)
    let narrow = CGRect(x: 2600, y: -35, width: 300, height: 1112)
    let clamped = islandToastFrame(notch: notch, screen: narrow)
    #expect(clamped.minX >= narrow.minX && clamped.maxX <= narrow.maxX)
}

@Test func meetingTextCountsDown() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    func slot(_ startMinutes: Double, _ length: Double = 30) -> MeetingSlot {
        let start = now.addingTimeInterval(startMinutes * 60)
        return MeetingSlot(start: start, end: start.addingTimeInterval(length * 60))
    }
    #expect(meetingText([slot(11.5)], now: now) == "Meeting in 12 min")
    #expect(meetingText([slot(0.2)], now: now) == "Meeting in 1 min")
    #expect(meetingText([slot(31)], now: now) == nil)
    #expect(meetingText([slot(-2)], now: now) == "Meeting now")
    #expect(meetingText([slot(-6)], now: now) == nil)
    #expect(meetingText([slot(-3, 2)], now: now) == nil)
    #expect(meetingText([slot(20), slot(-1)], now: now) == "Meeting now")
    #expect(meetingText([slot(20), slot(8)], now: now) == "Meeting in 8 min")
    #expect(meetingText([], now: now) == nil)
}

private func notificationData(_ request: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: ["req": request], format: .binary, options: 0)
}

@Test func noticeDecodesGenericRecord() throws {
    let data = try notificationData(["titl": "Romane Meurisse", "subt": "Retour Test", "body": "Hello\nDiviyan"])
    let notice = try #require(parseNotificationRecord(data, id: 7, app: "com.apple.mail"))
    #expect(notice == IslandNotice(id: 7, app: "com.apple.mail", title: "Romane Meurisse", detail: "Retour Test", body: "Hello Diviyan", link: nil))
}

@Test func noticeDecodesDiscordRecord() throws {
    let link = "discord://discord.com/channels/1/2/3"
    let usda = try NSKeyedArchiver.archivedData(withRootObject: ["fallbackDeepLink": link] as NSDictionary, requiringSecureCoding: false)
    let data = try notificationData(["titl": "\u{2068}Pavani\u{2069} (\u{2068}#paris\u{2069}, \u{2068}Equipe\u{2069})", "body": "retard", "usda": usda])
    let notice = try #require(parseNotificationRecord(data, id: 9, app: discordBundleID))
    #expect(notice.title == "Pavani")
    #expect(notice.detail == "#paris · Equipe")
    #expect(notice.link?.absoluteString == link)
}

@Test func garbageNoticeIsRejected() {
    #expect(parseNotificationRecord(Data("x".utf8), id: 1, app: "a") == nil)
}

@Test func ignoredApps() {
    #expect(isIgnoredNotificationApp("com.apple.scripteditor2"))
    #expect(isIgnoredNotificationApp("local.celestia.shell"))
    #expect(isIgnoredNotificationApp("_system_center_:com.apple.softwareupdatenotification"))
    #expect(!isIgnoredNotificationApp(discordBundleID))
}

@Test func cursorSeedsThenReturnsFreshRecords() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    var cursor = FeedCursor()
    #expect(cursor.accept([(id: 10, delivered: now), (id: 12, delivered: now)], now: now) == [])
    #expect(cursor.last == 12)
    let fresh = cursor.accept([(id: 12, delivered: now), (id: 13, delivered: now.addingTimeInterval(-31)), (id: 14, delivered: now.addingTimeInterval(-2))], now: now)
    #expect(fresh == [14])
    #expect(cursor.last == 14)
    #expect(cursor.accept([(id: 3, delivered: now)], now: now) == [])
    #expect(cursor.last == 3)
    #expect(cursor.accept([], now: now) == [])
    #expect(cursor.last == 3)
}

@Test func queueReplacesQueuedNowPlaying() {
    let first = SpotifyTrack(id: "a", title: "A", artist: "x", isPlaying: true, position: 0, duration: 1)
    let second = SpotifyTrack(id: "b", title: "B", artist: "x", isPlaying: true, position: 0, duration: 1)
    let notice = IslandNotice(id: 1, app: "a", title: "t", detail: nil, body: "b", link: nil)
    var queue = IslandQueue()
    queue.push(.nowPlaying(first))
    queue.push(.notice(notice))
    queue.push(.nowPlaying(second))
    #expect(queue.pop() == .notice(notice))
    #expect(queue.pop() == .nowPlaying(second))
    #expect(queue.pop() == nil)
    #expect(queue.isEmpty)
}

@Test func announceRules() {
    func track(_ id: String, playing: Bool) -> SpotifyTrack {
        SpotifyTrack(id: id, title: id, artist: "x", isPlaying: playing, position: 0, duration: 1)
    }
    #expect(shouldAnnounce(previous: nil, current: track("a", playing: true)))
    #expect(!shouldAnnounce(previous: track("a", playing: true), current: track("a", playing: true)))
    #expect(shouldAnnounce(previous: track("a", playing: true), current: track("b", playing: true)))
    #expect(shouldAnnounce(previous: track("a", playing: false), current: track("a", playing: true)))
    #expect(!shouldAnnounce(previous: track("a", playing: true), current: track("a", playing: false)))
    #expect(!shouldAnnounce(previous: track("a", playing: true), current: nil))
}
