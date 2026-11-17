import AppKit
import ShellCore

@MainActor
final class SpotifySensor: NSObject, ObservableObject {
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

    private static let changed = Notification.Name("com.spotify.client.PlaybackStateChanged")
    nonisolated private static let automationDenied = -1743
    nonisolated private static let artworkPixels = 128
    private static let queue = DispatchQueue(label: "local.celestia.shell.spotify", qos: .userInitiated)

    private var isObserving = false
    private var terminationObserver: NSObjectProtocol?
    private var artworkTrackID: String?

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: spotifyBundleID).isEmpty
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(playbackChanged(_:)), name: Self.changed, object: nil, suspensionBehavior: .deliverImmediately
        )
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == spotifyBundleID else { return }
            MainActor.assumeIsolated { self?.apply(nil) }
        }
        query()
    }

    func stop() {
        DistributedNotificationCenter.default().removeObserver(self, name: Self.changed, object: nil)
        if let terminationObserver { NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver) }
        terminationObserver = nil
        isObserving = false
        artwork = nil
        artworkTrackID = nil
    }

    @objc private func playbackChanged(_ note: Notification) {
        apply(parseSpotifyPayload(note.userInfo ?? [:]))
    }

    func previous() { send("previous track") }
    func playPause() { send("playpause") }
    func next() { send("next track") }

    private func apply(_ track: SpotifyTrack?) {
        measuredAt = Date()
        guard let track else {
            state = .notRunning
            artwork = nil
            artworkTrackID = nil
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
        let source = spotifyScript("""
        if player state is stopped then return {}
                set t to current track
                return {id of t, name of t, artist of t, duration of t, player state as string, player position}
        """)
        Self.queue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let denied = (error?[NSAppleScript.errorNumber] as? Int) == Self.automationDenied
            let track = result.flatMap(Self.track(from:))
            Task { @MainActor in
                guard let self, self.isObserving else { return }
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
        let source = spotifyScript(command)
        Self.queue.async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private func loadArtwork(for trackID: String) {
        guard trackID != artworkTrackID else { return }
        artworkTrackID = trackID
        artwork = nil
        let source = spotifyScript("return {id of current track, artwork url of current track}")
        Self.queue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            guard result?.atIndex(1)?.stringValue == trackID,
                  let url = result?.atIndex(2)?.stringValue.flatMap(URL.init(string:))
            else { return }
            Task { @MainActor [weak self] in
                let thumbnail = await Task.detached(priority: .utility) { () -> CGImage? in
                    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
                    return Self.thumbnail(data)
                }.value
                guard let thumbnail, let self, self.artworkTrackID == trackID, self.isObserving else { return }
                self.artwork = NSImage(cgImage: thumbnail, size: NSSize(width: Self.artworkPixels / 2, height: Self.artworkPixels / 2))
            }
        }
    }

    nonisolated private static func thumbnail(_ data: Data) -> CGImage? {
        guard let source = NSBitmapImageRep(data: data)?.cgImage,
              let context = CGContext(
                data: nil, width: artworkPixels, height: artworkPixels, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: artworkPixels, height: artworkPixels))
        return context.makeImage()
    }
}
