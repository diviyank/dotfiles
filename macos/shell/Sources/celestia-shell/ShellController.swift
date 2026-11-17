import AppKit
import Combine
import ShellCore

@MainActor
final class ShellController: NSObject {
    private let model = BarModel()
    private let launcher = LauncherController()
    private lazy var dashboard = DashboardPanel(model: model)
    private lazy var osd = OSDPanel(model: model)
    private var chromes: [String: DisplayChrome] = [:]
    private var watchers: [FileWatcher] = []
    private var subscriptions = Set<AnyCancellable>()

    override init() {
        super.init()
        rebuildChromes()
        watchers = [
            FileWatcher(ShellPaths.colors) { [weak self] in self?.model.reloadPalette() },
            FileWatcher(ShellPaths.settings) { [weak self] in self?.settingsChanged() },
        ]
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildChromes), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refresh), name: shellRefreshNotification, object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(toggleDashboard), name: dashboardToggleNotification, object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspace.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        VolumeSensor.shared.changes
            .sink { [weak self] in self?.flashOSD() }
            .store(in: &subscriptions)
        model.$displays
            .sink { [weak self] displays in self?.applyFullscreen(displays) }
            .store(in: &subscriptions)
        model.refresh()
    }

    @objc private func refresh() {
        model.refresh()
    }

    @objc private func toggleDashboard() {
        guard let screen = screenUnderMouse() else { return }
        dashboard.togglePinned(on: screen)
    }

    private func flashOSD() {
        guard let screen = screenUnderMouse() else { return }
        osd.flash(on: screen)
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
    }

    @objc private func rebuildChromes() {
        dashboard.close()
        osd.close()
        chromes.values.forEach { $0.close() }
        chromes = [:]
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID else { continue }
            chromes[uuid] = DisplayChrome(screen: screen, uuid: uuid, model: model, dashboard: dashboard, osd: osd)
        }
        applyFullscreen(model.displays)
        model.refresh()
    }

    private func applyFullscreen(_ displays: [ShellCore.BarDisplay]) {
        for display in displays {
            chromes[display.uuid]?.setVisible(!display.isFullscreen)
        }
    }

    private func settingsChanged() {
        guard model.reloadSettings() else { return }
        Task.detached(priority: .utility) {
            _ = runProcess("/bin/sh", [ShellPaths.applyYabai.path])
        }
    }
}
