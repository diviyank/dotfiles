import Foundation

public struct DiscordTitle: Equatable, Sendable {
    public let sender: String
    public let place: String?

    public init(sender: String, place: String?) {
        self.sender = sender
        self.place = place
    }
}

public struct DiscordNote: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let sender: String
    public let place: String?
    public let body: String
    public let link: URL?
}

public let discordBundleID = "com.hnc.discord"

private let isolationMarks = CharacterSet(charactersIn: "\u{2066}\u{2067}\u{2068}\u{2069}")

private func stripIsolation(_ text: String) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.filter { !isolationMarks.contains($0) }))
        .trimmingCharacters(in: .whitespaces)
}

public func parseDiscordTitle(_ raw: String) -> DiscordTitle {
    let title = stripIsolation(raw)
    guard title.hasSuffix(")"), let open = title.range(of: " (", options: .backwards) else {
        return DiscordTitle(sender: title, place: nil)
    }
    let inner = title[open.upperBound..<title.index(before: title.endIndex)]
    let place = inner.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
    return DiscordTitle(sender: String(title[..<open.lowerBound]), place: place.isEmpty ? nil : place)
}

private func deepLink(in archive: Data) -> URL? {
    guard let plist = try? PropertyListSerialization.propertyList(from: archive, format: nil) as? [String: Any],
          let objects = plist["$objects"] as? [Any],
          let link = objects.lazy.compactMap({ $0 as? String }).first(where: { $0.hasPrefix("discord://") })
    else { return nil }
    return URL(string: link)
}

public func parseDiscordRecord(_ data: Data) -> DiscordNote? {
    guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let request = plist["req"] as? [String: Any],
          let title = request["titl"] as? String
    else { return nil }
    let parsed = parseDiscordTitle(title)
    let body = stripIsolation((request["body"] as? String ?? "").split(whereSeparator: \.isNewline).joined(separator: " "))
    return DiscordNote(
        id: request["iden"] as? String ?? UUID().uuidString,
        sender: parsed.sender,
        place: parsed.place,
        body: body,
        link: (request["usda"] as? Data).flatMap(deepLink(in:))
    )
}
