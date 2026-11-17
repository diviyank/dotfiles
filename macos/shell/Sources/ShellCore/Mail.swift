import Foundation

public struct MailSummary: Equatable, Hashable, Sendable {
    public let sender: String
    public let subject: String
    public let messageID: String

    public init(sender: String, subject: String, messageID: String) {
        self.sender = sender
        self.subject = subject
        self.messageID = messageID
    }
}

public let mailUnitSeparator = "\u{1F}"
public let mailRecordSeparator = "\u{1E}"

public func senderName(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard let open = trimmed.firstIndex(of: "<") else { return trimmed }
    let name = trimmed[..<open].trimmingCharacters(in: CharacterSet.whitespaces.union(["\""]))
    if !name.isEmpty { return name }
    return trimmed[trimmed.index(after: open)...].trimmingCharacters(in: CharacterSet(charactersIn: "> "))
}

public func parseMailSummaries(_ text: String, limit: Int = 5) -> [MailSummary] {
    let summaries = text.components(separatedBy: mailRecordSeparator).compactMap { record -> MailSummary? in
        let fields = record.components(separatedBy: mailUnitSeparator)
        guard fields.count == 3 else { return nil }
        let subject = fields[1].split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return MailSummary(
            sender: senderName(fields[0]),
            subject: subject.isEmpty ? "(No subject)" : subject,
            messageID: fields[2]
        )
    }
    return Array(summaries.prefix(limit))
}

public func mailMessageURL(_ messageID: String) -> URL? {
    let bare = messageID.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
    guard !bare.isEmpty else { return nil }
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "<>")
    guard let encoded = bare.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
    return URL(string: "message://%3C\(encoded)%3E")
}
