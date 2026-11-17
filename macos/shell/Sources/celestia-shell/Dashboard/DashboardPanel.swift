import AppKit
import ShellCore
import SwiftUI

let dashboardToggleNotification = Notification.Name("local.celestia.shell.dashboard")

final class DashboardWindow: NSPanel {
    var isPinned = false

    override var canBecomeKey: Bool { isPinned }
    override var canBecomeMain: Bool { false }

    static func make() -> DashboardWindow {
        let window = DashboardWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
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
    private var pendingOpen: DispatchWorkItem?
    private var pendingClose: DispatchWorkItem?
    private var pendingTeardown: DispatchWorkItem?
    private var previousApp: NSRunningApplication?
    private var escapeMonitor: Any?
    private var hasContent = false

    static let fillet: CGFloat = Theme.Bar.innerRadius
    private static let openDelay = 0.08
    private static let closeDelay = 0.2
    private static let growDuration = 0.4

    init(model: BarModel) {
        self.model = model
        data = DashboardModel { [weak model] in model?.settings ?? .defaults }
    }

    var isOpen: Bool { window.isVisible && revealed }

    func zoneHover(screen: NSScreen, inside: Bool) {
        overZone = inside
        pendingOpen?.cancel()
        guard !window.isPinned else { return }
        guard inside else { return scheduleClose() }
        pendingClose?.cancel()
        if isOpen {
            if self.screen != screen { show(on: screen) }
        } else {
            pendingOpen = schedule(after: Self.openDelay) { [weak self] in self?.show(on: screen) }
        }
    }

    func panelHover(_ inside: Bool) {
        overPanel = inside
        if inside { pendingClose?.cancel() } else if !window.isPinned { scheduleClose() }
    }

    func togglePinned(on screen: NSScreen) {
        if window.isPinned && isOpen { return close() }
        pendingOpen?.cancel()
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
        pendingOpen?.cancel()
        pendingClose?.cancel()
        overZone = false
        overPanel = false
        let wasPinned = window.isPinned
        window.isPinned = false
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        guard window.isVisible else { return }
        withAnimation(Motion.emphasized) { revealed = false }
        if wasPinned && restoringFocus { previousApp?.activate() }
        previousApp = nil
        pendingTeardown?.cancel()
        pendingTeardown = schedule(after: Self.growDuration) { [weak self] in
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
        window.setFrame(frame, display: true)
        self.screen = screen
        window.orderFrontRegardless()
        withAnimation(Motion.emphasized) { revealed = true }
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
                .opacity(panel.revealed ? 1 : 0)
                .animation(Motion.fade, value: panel.revealed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask(alignment: .top) {
            Rectangle().scaleEffect(y: panel.revealed ? 1 : 0.001, anchor: .top)
        }
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
