import AppKit
import ShellCore
import SwiftUI

let dashboardToggleNotification = Notification.Name("local.celestia.shell.dashboard")

final class DashboardWindow: SlidingPanel {
    var isPinned = false

    override var canBecomeKey: Bool { isPinned }
    override var canBecomeMain: Bool { false }

    static func make() -> DashboardWindow {
        let window = DashboardWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.configureAsChrome()
        return window
    }
}

@MainActor
final class DashboardPanel: ObservableObject {
    @Published private(set) var revealed = false
    @Published private(set) var topInset: CGFloat = 0

    let model: BarModel
    let data: DashboardModel
    private let window = DashboardWindow.make()
    private var screen: NSScreen?
    private var overZone = false
    private var overPanel = false
    private var pendingClose: DispatchWorkItem?
    private var pendingTeardown: DispatchWorkItem?
    private var previousApp: NSRunningApplication?
    private var escapeMonitor: Any?
    private var hasContent = false

    static let fillet: CGFloat = Theme.Bar.innerRadius
    private static let closeDelay = 0.2

    init(model: BarModel) {
        self.model = model
        data = DashboardModel { [weak model] in model?.settings ?? .defaults }
    }

    var isOpen: Bool { window.isVisible && revealed }

    func zoneHover(screen: NSScreen, inside: Bool) {
        overZone = inside
        guard !window.isPinned else { return }
        guard inside else { return scheduleClose() }
        pendingClose?.cancel()
        if !isOpen || self.screen != screen { show(on: screen) }
    }

    func panelHover(_ inside: Bool) {
        overPanel = inside
        if inside { pendingClose?.cancel() } else if !window.isPinned { scheduleClose() }
    }

    func togglePinned(on screen: NSScreen) {
        if window.isPinned && isOpen { return close() }
        pendingClose?.cancel()
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        window.isPinned = true
        show(on: screen)
        window.makeKey()
        escapeMonitor = escapeMonitor ?? NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, event.window === self.window else { return event }
            self.close()
            return nil
        }
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        close(restoringFocus: false)
    }

    func close(restoringFocus: Bool = true) {
        pendingClose?.cancel()
        overZone = false
        overPanel = false
        let wasPinned = window.isPinned
        window.isPinned = false
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        guard window.isVisible else { return }
        revealed = false
        window.slide(to: window.frame.offsetBy(dx: 0, dy: window.frame.height), entering: false)
        if wasPinned && restoringFocus { previousApp?.activate() }
        previousApp = nil
        pendingTeardown?.cancel()
        pendingTeardown = schedule(after: Motion.exitDuration + 0.05) { [weak self] in
            guard let self, !self.revealed else { return }
            self.window.orderOut(nil)
            self.window.contentView = NSView()
            self.hasContent = false
            self.screen = nil
            self.data.closed()
        }
    }

    private func show(on screen: NSScreen) {
        let content = CGSize(width: Theme.Dashboard.width, height: Theme.Dashboard.height)
        topInset = dashboardTopInset(border: model.settings.border, safeAreaTop: screen.safeAreaInsets.top)
        let frame = dashboardFrame(screen: screen.frame, content: content, topInset: topInset, fillet: Self.fillet)
        pendingTeardown?.cancel()
        if !hasContent {
            hasContent = true
            let host = NSHostingView(rootView: DashboardHost(panel: self, model: model, data: data))
            host.sizingOptions = []
            window.contentView = host
            data.opened()
        }
        let wasRevealed = revealed && window.isVisible && self.screen == screen
        self.screen = screen
        revealed = true
        guard !wasRevealed else { return }
        if !window.isVisible || window.frame.size != frame.size {
            window.setFrame(frame.offsetBy(dx: 0, dy: frame.height), display: false)
        }
        window.contentView?.layoutSubtreeIfNeeded()
        window.orderFrontRegardless()
        window.slide(to: frame, entering: true)
    }

    private func scheduleClose() {
        pendingClose?.cancel()
        pendingClose = schedule(after: Self.closeDelay) { [weak self] in
            guard let self, !self.overZone, !self.overPanel, !self.window.isPinned else { return }
            self.close()
        }
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) -> DispatchWorkItem {
        let item = DispatchWorkItem { MainActor.assumeIsolated(work) }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }
}

struct DashboardHost: View {
    @ObservedObject var panel: DashboardPanel
    @ObservedObject var model: BarModel
    let data: DashboardModel

    var body: some View {
        ZStack(alignment: .top) {
            DashboardShape(fillet: DashboardPanel.fillet, radius: Theme.Bar.innerRadius)
                .fill(model.color("surface"))
            DashboardView(panel: panel, model: model, data: data)
                .padding(.top, panel.topInset)
                .padding(.horizontal, DashboardPanel.fillet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(HoverTracker { inside, _ in panel.panelHover(inside) })
        .ignoresSafeArea()
    }
}

struct DashboardZone: View {
    let onHover: (Bool) -> Void

    var body: some View {
        Color.black.opacity(0.01)
            .overlay(HoverTracker { inside, _ in onHover(inside) })
            .ignoresSafeArea()
    }
}
