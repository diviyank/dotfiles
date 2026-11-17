import Foundation
import Testing
@testable import ShellCore

@Test func meetingLinkFromNotes() {
    let notes = "Agenda\nJoin: https://meet.google.com/abc-defg-hij\nThanks"
    #expect(meetingLink(url: nil, location: nil, notes: notes) == URL(string: "https://meet.google.com/abc-defg-hij"))
}

@Test func meetingLinkPrefersEventURL() {
    let link = meetingLink(url: URL(string: "https://us02web.zoom.us/j/123?pwd=x"), location: nil, notes: "https://meet.google.com/aaa-bbbb-ccc")
    #expect(link == URL(string: "https://us02web.zoom.us/j/123?pwd=x"))
}

@Test func meetingLinkTeamsInLocation() {
    let location = "Microsoft Teams Meeting <https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y>"
    #expect(meetingLink(url: nil, location: location, notes: nil) == URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y"))
}

@Test func meetingLinkIgnoresOtherURLs() {
    #expect(meetingLink(url: URL(string: "https://example.com/doc"), location: "Room 4", notes: "see https://docs.google.com/x") == nil)
}
