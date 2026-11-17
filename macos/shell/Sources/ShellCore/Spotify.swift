import Foundation

public struct SpotifyTrack: Equatable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let isPlaying: Bool
    public let position: Double
    public let duration: Double

    public init(id: String, title: String, artist: String, isPlaying: Bool, position: Double, duration: Double) {
        self.id = id
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.position = position
        self.duration = duration
    }
}

public func parseSpotifyPayload(_ info: [AnyHashable: Any]) -> SpotifyTrack? {
    guard let id = info["Track ID"] as? String,
          let state = info["Player State"] as? String, state != "Stopped"
    else { return nil }
    let durationMs = (info["Duration"] as? NSNumber)?.doubleValue ?? 0
    return SpotifyTrack(
        id: id,
        title: info["Name"] as? String ?? "",
        artist: info["Artist"] as? String ?? "",
        isPlaying: state == "Playing",
        position: (info["Playback Position"] as? NSNumber)?.doubleValue ?? 0,
        duration: durationMs / 1000
    )
}

public let spotifyBundleID = "com.spotify.client"

public func spotifyScript(_ body: String) -> String {
    """
    if application id "\(spotifyBundleID)" is running then
        with timeout of 2 seconds
            tell application id "\(spotifyBundleID)"
                \(body)
            end tell
        end timeout
    end if
    """
}
