import Testing
@testable import ShellCore

@Test func badgeTextCapsLargeCounts() {
    #expect(badgeText("176") == "99+")
    #expect(badgeText("99") == "99")
    #expect(badgeText("7") == "7")
    #expect(badgeText("•") == "•")
}

@Test func emptySpacesAreHiddenUnlessVisible() {
    let window = BarWindow(id: 1, pid: 1, app: "kitty", title: "", hasFocus: false)
    let spaces = [
        BarSpace(number: 1, label: "one", isVisible: false, windows: [window]),
        BarSpace(number: 2, label: "two", isVisible: false, windows: []),
        BarSpace(number: 3, label: "three", isVisible: true, windows: []),
    ]
    #expect(shownSpaces(spaces).map(\.number) == [1, 3])
}

@Test func senderNameDropsTheAddress() {
    #expect(senderName("Jane Doe <jane@x.com>") == "Jane Doe")
    #expect(senderName("\"Doe, Jane\" <jane@x.com>") == "Doe, Jane")
    #expect(senderName("<jane@x.com>") == "jane@x.com")
    #expect(senderName("jane@x.com") == "jane@x.com")
}

@Test func mailSummariesParseFromSeparatedRecords() {
    let unit = "\u{1F}", record = "\u{1E}"
    let text = "Jane <j@x>\(unit)Hello\nthere\(unit)a1@x\(record)Bob <b@x>\(unit)Invoice\(unit)b2@x\(record)broken\(record)"
    #expect(parseMailSummaries(text) == [
        MailSummary(sender: "Jane", subject: "Hello there", messageID: "a1@x"),
        MailSummary(sender: "Bob", subject: "Invoice", messageID: "b2@x"),
    ])
    #expect(parseMailSummaries(text, limit: 1).count == 1)
    #expect(parseMailSummaries("Jane\(unit)\(unit)z@x\(record)") == [
        MailSummary(sender: "Jane", subject: "(No subject)", messageID: "z@x"),
    ])
}

@Test func mailMessageURLOpensTheMessageInMail() {
    #expect(mailMessageURL("abc+1@host.com")?.absoluteString == "message://%3Cabc+1@host.com%3E")
    #expect(mailMessageURL("<abc@host>")?.absoluteString == "message://%3Cabc@host%3E")
    #expect(mailMessageURL("") == nil)
}
