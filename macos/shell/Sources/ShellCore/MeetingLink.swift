import Foundation

private let meetingHosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com"]

public func meetingLink(url: URL?, location: String?, notes: String?) -> URL? {
    if let url, isMeeting(url) { return url }
    return [location, notes].compactMap { $0 }.lazy.compactMap(firstMeetingURL).first
}

private func isMeeting(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
}

private func firstMeetingURL(in text: String) -> URL? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    return detector.matches(in: text, range: range).lazy.compactMap(\.url).first(where: isMeeting)
}
