import Foundation
import Testing
@testable import ShellCore

private func payload(state: String) -> [AnyHashable: Any] {
    [
        "Track ID": "spotify:track:abc", "Name": "Song", "Artist": "Band",
        "Player State": state, "Playback Position": 42.5, "Duration": 215_000,
    ]
}

@Test func parsesPlayingTrack() {
    let track = parseSpotifyPayload(payload(state: "Playing"))
    #expect(track == SpotifyTrack(id: "spotify:track:abc", title: "Song", artist: "Band", isPlaying: true, position: 42.5, duration: 215.0))
}

@Test func parsesPausedTrack() {
    #expect(parseSpotifyPayload(payload(state: "Paused"))?.isPlaying == false)
}

@Test func stoppedOrIncompleteIsNothing() {
    #expect(parseSpotifyPayload(payload(state: "Stopped")) == nil)
    var missing = payload(state: "Playing")
    missing["Track ID"] = nil
    #expect(parseSpotifyPayload(missing) == nil)
}

@Test func spotifyScriptNeverLaunchesAndTimesOut() {
    let script = spotifyScript("playpause")
    let lines = script.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    #expect(lines.first == #"if application id "com.spotify.client" is running then"#)
    #expect(lines.contains("with timeout of 2 seconds"))
    #expect(lines.contains(#"tell application id "com.spotify.client""#))
    #expect(lines.contains("playpause"))
    #expect(lines.last == "end if")
}
