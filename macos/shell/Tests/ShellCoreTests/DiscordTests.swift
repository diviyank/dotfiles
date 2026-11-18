import Foundation
import ShellCore
import Testing

private let link = "discord://discord.com/channels/807615141561630721/1391767923504320644/1572538352215793726"

private func record(title: String, body: String, deepLink: String? = link) throws -> Data {
    var request: [String: Any] = ["titl": title, "body": body, "iden": "1572538352215793726"]
    if let deepLink {
        request["usda"] = try NSKeyedArchiver.archivedData(
            withRootObject: ["fallbackDeepLink": deepLink] as NSDictionary, requiringSecureCoding: false)
    }
    return try PropertyListSerialization.data(fromPropertyList: ["app": "com.hnc.discord", "req": request], format: .binary, options: 0)
}

@Test func channelTitleSplitsSenderAndPlace() {
    let title = "\u{2068}Fayçal Djerrab\u{2069} (\u{2068}#clairvoyant-support\u{2069}, \u{2068}Equipe\u{2069})"
    #expect(parseDiscordTitle(title) == DiscordTitle(sender: "Fayçal Djerrab", place: "#clairvoyant-support · Equipe"))
}

@Test func threadTitleKeepsQuotedName() {
    let title = "\u{2068}Mohamed\u{2069} (\u{2068}\"Review MErge Back\"\u{2069}, \u{2068}clairvoyant-v2\u{2069})"
    #expect(parseDiscordTitle(title) == DiscordTitle(sender: "Mohamed", place: "\"Review MErge Back\" · clairvoyant-v2"))
}

@Test func directMessageTitleHasNoPlace() {
    #expect(parseDiscordTitle("\u{2068}Pavani\u{2069}") == DiscordTitle(sender: "Pavani", place: nil))
    #expect(parseDiscordTitle("Ann (Smith)") == DiscordTitle(sender: "Ann", place: "Smith"))
}

@Test func recordDecodesIntoNote() throws {
    let data = try record(title: "\u{2068}Pavani\u{2069} (\u{2068}#paris\u{2069}, \u{2068}Equipe\u{2069})", body: "Hello,\nje vais avoir du retard")
    let note = try #require(parseDiscordRecord(data))
    #expect(note.sender == "Pavani")
    #expect(note.place == "#paris · Equipe")
    #expect(note.body == "Hello, je vais avoir du retard")
    #expect(note.link?.absoluteString == link)
    #expect(note.id == "1572538352215793726")
}

@Test func recordWithoutDeepLinkStillDecodes() throws {
    let note = try #require(parseDiscordRecord(try record(title: "Bob", body: "hi", deepLink: nil)))
    #expect(note.link == nil)
}

@Test func garbageRecordIsRejected() {
    #expect(parseDiscordRecord(Data("nope".utf8)) == nil)
}
