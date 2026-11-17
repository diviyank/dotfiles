import AppKit
import Combine
import ShellCore
import SwiftUI

final class ChromePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(frame: NSRect, clickThrough: Bool, content: some View) -> ChromePanel {
        let panel = ChromePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = clickThrough
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(frame, display: false)
        return panel
    }
}

@MainActor
final class DisplayChrome {
    let uuid: String
    private let frame: ChromePanel
    private let bar: ChromePanel
    private let popouts: PopoutPanel
    private let zone: ChromePanel
    private var settingsSubscription: AnyCancellable?
    private var isVisible = false

    init(screen: NSScreen, uuid: String, model: BarModel, dashboard: DashboardPanel) {
        self.uuid = uuid
        frame = ChromePanel.make(frame: screen.frame, clickThrough: true, content: FrameView(model: model))
        popouts = PopoutPanel(screen: screen.frame, model: model)
        var strip = screen.frame
        strip.size.width = Theme.Bar.width
        bar = ChromePanel.make(frame: strip, clickThrough: false, content: BarView(model: model, uuid: uuid, popouts: popouts, dashboard: dashboard))
        zone = ChromePanel.make(
            frame: Self.zoneFrame(screen, border: model.settings.border), clickThrough: false,
            content: DashboardZone { [weak dashboard, weak screen] inside in
                guard let screen else { return }
                dashboard?.zoneHover(screen: screen, inside: inside)
            }
        )
        settingsSubscription = model.$settings.sink { [weak zone, weak screen] settings in
            guard let zone, let screen else { return }
            zone.setFrame(Self.zoneFrame(screen, border: settings.border), display: true)
        }
        setVisible(true)
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        for panel in [frame, bar, zone] {
            if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        }
        if !visible { popouts.hide() }
    }

    func close() {
        frame.close()
        bar.close()
        zone.close()
        popouts.close()
    }
}

extension DisplayChrome {
    private static func zoneFrame(_ screen: NSScreen, border: Double) -> NSRect {
        hoverZone(screen: screen.frame, width: Theme.Dashboard.width, border: border, safeAreaTop: screen.safeAreaInsets.top)
    }
}

extension NSScreen {
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
