import AppKit
import Combine
@preconcurrency import EventKit
import ShellCore
import SwiftUI

@MainActor
final class IslandController: ObservableObject {
    @Published private(set) var shown: IslandEvent?
    @Published private(set) var expanded = false
    @Published private(set) var now = Date()
    @Published private(set) var meeting: String?

    let spotify = SpotifySensor()
    let notch: CGRect
    private let screen: CGRect
    private let dashboard: DashboardPanel
    private lazy var panel = ChromePanel.make(
        frame: islandIdleFrame(notch: notch, screen: screen), clickThrough: true, content: IslandView(island: self, model: model)
    )
    private let model: BarModel
    private var feed: NotificationFeed?
    private var queue = IslandQueue()
    private var lastTrack: SpotifyTrack?
    private var subscriptions = Set<AnyCancellable>()
    private var minuteTimer: Timer?
    private var pending: DispatchWorkItem?
    private var calendarObserver: NSObjectProtocol?
    private lazy var events = EKEventStore()
    private var isVisible = true
    private let startedAt = Date()
    private static let launchQuiet: TimeInterval = 3
    private static let dashboardRetry: TimeInterval = 1

    init?(screen: NSScreen, dashboard: DashboardPanel, model: BarModel) {
        guard let notch = notchRect(left: screen.auxiliaryTopLeftArea, right: screen.auxiliaryTopRightArea) else { return nil }
        self.notch = notch
        self.screen = screen.frame
        self.dashboard = dashboard
        self.model = model
        panel.orderFrontRegardless()
        feed = NotificationFeed { [weak self] notice in self?.push(.notice(notice)) }
        spotify.$state
            .map(\.track)
            .removeDuplicates()
            .sink { [weak self] track in self?.trackChanged(track) }
            .store(in: &subscriptions)
        spotify.start()
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            calendarObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: events, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshMeeting() }
            }
        }
        tick()
    }

    var isPlaying: Bool {
        if case .playing = spotify.state { return true }
        return false
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            panel.orderFrontRegardless()
            pump()
        } else {
            queue = IslandQueue()
            panel.orderOut(nil)
        }
    }

    func close() {
        pending?.cancel()
        minuteTimer?.invalidate()
        spotify.stop()
        if let calendarObserver { NotificationCenter.default.removeObserver(calendarObserver) }
        feed = nil
        panel.contentView = nil
        panel.close()
    }

    func activate(_ event: IslandEvent) {
        switch event {
        case .notice(let notice):
            if let link = notice.link {
                NSWorkspace.shared.open(link)
            } else {
                openApplication(notice.app)
            }
        case .nowPlaying:
            openApplication(spotifyBundleID)
        }
        dismiss()
    }

    private func openApplication(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func trackChanged(_ track: SpotifyTrack?) {
        defer { lastTrack = track }
        guard Date().timeIntervalSince(startedAt) > Self.launchQuiet, shouldAnnounce(previous: lastTrack, current: track), let track else { return }
        push(.nowPlaying(track))
    }

    private func push(_ event: IslandEvent) {
        guard isVisible else { return }
        queue.push(event)
        pump()
    }

    private func pump() {
        guard shown == nil, isVisible, !queue.isEmpty else { return }
        guard !dashboard.isOpen else {
            pending = schedule(after: Self.dashboardRetry) { [weak self] in self?.pump() }
            return
        }
        guard let event = queue.pop() else { return }
        panel.setFrame(islandToastFrame(notch: notch, screen: screen), display: true)
        panel.ignoresMouseEvents = false
        shown = event
        withAnimation(Motion.enter) { expanded = true }
        pending = schedule(after: Self.duration(of: event)) { [weak self] in self?.dismiss() }
    }

    private func dismiss() {
        pending?.cancel()
        panel.ignoresMouseEvents = true
        withAnimation(Motion.exit) { expanded = false }
        pending = schedule(after: Motion.exitDuration) { [weak self] in
            guard let self else { return }
            self.shown = nil
            self.panel.setFrame(islandIdleFrame(notch: self.notch, screen: self.screen), display: true)
            self.pump()
        }
    }

    private static func duration(of event: IslandEvent) -> TimeInterval {
        switch event {
        case .notice: 5
        case .nowPlaying: 4
        }
    }

    private func tick() {
        now = Date()
        refreshMeeting()
        let nextMinute = (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60
        minuteTimer = Timer.scheduledTimer(withTimeInterval: nextMinute - now.timeIntervalSinceReferenceDate + 0.05, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func refreshMeeting() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return meeting = nil }
        let now = Date()
        let predicate = events.predicateForEvents(withStart: now.addingTimeInterval(-5 * 60), end: now.addingTimeInterval(30 * 60), calendars: nil)
        let slots = events.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .map { MeetingSlot(start: $0.startDate, end: $0.endDate) }
        meeting = meetingText(slots, now: now)
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) -> DispatchWorkItem {
        let item = DispatchWorkItem { MainActor.assumeIsolated(work) }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }
}
