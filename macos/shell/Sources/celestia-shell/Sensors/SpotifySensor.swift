import AppKit
import ShellCore

@MainActor
final class SpotifySensor: ObservableObject {
    enum State: Equatable {
        case notRunning
        case denied
        case playing(SpotifyTrack)
        case paused(SpotifyTrack)

        var track: SpotifyTrack? {
            switch self {
            case .playing(let track), .paused(let track): track
            case .notRunning, .denied: nil
            }
        }
    }

    @Published private(set) var state: State = .notRunning
    @Published private(set) var artwork: NSImage?
    @Published private(set) var measuredAt = Date()

    private static let bundleID = "com.spotify.client"
    private static let changed = Notification.Name("com.spotify.client.PlaybackStateChanged")
    nonisolated private static let automationDenied = -1743
    nonisolated private static let artworkPixels = 128
    private static let queue = DispatchQueue(label: "local.celestia.shell.spotify", qos: .userInitiated)

    private var observer: NSObjectProtocol?
    private var artworkTrackID: String?

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(forName: Self.changed, object: nil, queue: .main) { [weak self] note in
            let track = parseSpotifyPayload(note.userInfo ?? [:])
            MainActor.assumeIsolated { self?.apply(track) }
        }
        query()
    }

    func stop() {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        observer = nil
        artwork = nil
        artworkTrackID = nil
    }

    func previous() { send("previous track") }
    func playPause() { send("playpause") }
    func next() { send("next track") }

    private func apply(_ track: SpotifyTrack?) {
        measuredAt = Date()
        guard let track else {
            state = .notRunning
            return
        }
        state = track.isPlaying ? .playing(track) : .paused(track)
        loadArtwork(for: track.id)
    }

    private func query() {
        guard isRunning else {
            state = .notRunning
            return
        }
        let source = """
        tell application id "\(Self.bundleID)"
            if player state is stopped then return {}
            set t to current track
            return {id of t, name of t, artist of t, duration of t, player state as string, player position}
        end tell
        """
        Self.queue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let denied = (error?[NSAppleScript.errorNumber] as? Int) == Self.automationDenied
            let track = result.flatMap(Self.track(from:))
            Task { @MainActor in
                guard let self, self.observer != nil else { return }
                if denied { self.state = .denied } else { self.apply(track) }
            }
        }
    }

    nonisolated private static func track(from list: NSAppleEventDescriptor) -> SpotifyTrack? {
        guard list.numberOfItems == 6, let id = list.atIndex(1)?.stringValue else { return nil }
        return SpotifyTrack(
            id: id,
            title: list.atIndex(2)?.stringValue ?? "",
            artist: list.atIndex(3)?.stringValue ?? "",
            isPlaying: list.atIndex(5)?.stringValue == "playing",
            position: list.atIndex(6)?.doubleValue ?? 0,
            duration: (list.atIndex(4)?.doubleValue ?? 0) / 1000
        )
    }

    private func send(_ command: String) {
        guard isRunning else { return }
        let source = "tell application id \"\(Self.bundleID)\" to \(command)"
        Self.queue.async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private func loadArtwork(for trackID: String) {
        guard trackID != artworkTrackID else { return }
        artworkTrackID = trackID
        artwork = nil
        let source = "tell application id \"\(Self.bundleID)\" to return artwork url of current track"
        Self.queue.async { [weak self] in
            var error: NSDictionary?
            let url = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue.flatMap(URL.init(string:))
            Task { @MainActor in
                guard let url, let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = Self.thumbnail(data),
                      let self, self.artworkTrackID == trackID, self.observer != nil
                else { return }
                self.artwork = image
            }
        }
    }

    nonisolated private static func thumbnail(_ data: Data) -> NSImage? {
        guard let source = NSBitmapImageRep(data: data)?.cgImage,
              let context = CGContext(
                data: nil, width: artworkPixels, height: artworkPixels, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: artworkPixels, height: artworkPixels))
        return context.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: artworkPixels / 2, height: artworkPixels / 2)) }
    }
}
