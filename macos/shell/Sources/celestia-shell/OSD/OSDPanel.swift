import AppKit
import ShellCore
import SwiftUI

final class OSDWindow: SlidingPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OSDPanel: ObservableObject {
    let model: BarModel
    private lazy var window: OSDWindow = {
        let window = OSDWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.configureAsChrome()
        let host = NSHostingView(rootView: OSDHost(model: model, panel: self))
        host.sizingOptions = []
        window.contentView = host
        return window
    }()
    private var screen: NSScreen?
    private var isOpen = false
    private var overPanel = false
    private var overZone = false
    private var pendingHide: DispatchWorkItem?
    private var brightnessTimer: Timer?

    static let fillet: CGFloat = Theme.Bar.innerRadius

    init(model: BarModel) {
        self.model = model
    }

    static var sliderCount: Int { BrightnessSensor.shared.isAvailable ? 2 : 1 }

    func frame(on screen: NSScreen) -> NSRect {
        osdFrame(
            screen: screen.frame, content: Theme.OSD.content(sliders: Self.sliderCount),
            border: model.settings.border, fillet: Self.fillet
        )
    }

    func flash(on screen: NSScreen) {
        show(on: screen)
        scheduleHide(after: Theme.OSD.hideDelay)
    }

    func zoneHover(screen: NSScreen, inside: Bool) {
        overZone = inside
        if inside {
            pendingHide?.cancel()
            show(on: screen)
        } else {
            scheduleHide(after: Theme.OSD.leaveDelay)
        }
    }

    func panelHover(_ inside: Bool) {
        overPanel = inside
        if inside { pendingHide?.cancel() } else { scheduleHide(after: Theme.OSD.leaveDelay) }
    }

    func close() {
        pendingHide?.cancel()
        stopPolling()
        overPanel = false
        overZone = false
        guard isOpen else { return }
        isOpen = false
        let hidden = window.frame.offsetBy(dx: window.frame.width, dy: 0)
        window.slide(to: hidden, entering: false) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isOpen else { return }
                self.window.orderOut(nil)
            }
        }
    }

    private func show(on screen: NSScreen) {
        let frame = frame(on: screen)
        guard !(isOpen && self.screen == screen && window.frame == frame) else { return }
        if !isOpen && (!window.isVisible || self.screen != screen || window.frame.size != frame.size) {
            window.setFrame(frame.offsetBy(dx: frame.width, dy: 0), display: false)
        }
        self.screen = screen
        isOpen = true
        BrightnessSensor.shared.read()
        window.contentView?.layoutSubtreeIfNeeded()
        window.orderFrontRegardless()
        window.slide(to: frame, entering: true)
        startPolling()
    }

    private func scheduleHide(after delay: TimeInterval) {
        pendingHide?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isMouseOver() { self.scheduleHide(after: Theme.OSD.hideDelay) } else { self.close() }
            }
        }
        pendingHide = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func isMouseOver() -> Bool {
        guard let screen, overPanel || overZone else { return false }
        let mouse = NSEvent.mouseLocation
        let zone = osdHoverZone(frame: frame(on: screen), screen: screen.frame, border: model.settings.border)
        return NSMouseInRect(mouse, window.frame, false) || NSMouseInRect(mouse, zone, false)
    }

    private func startPolling() {
        guard brightnessTimer == nil, BrightnessSensor.shared.isAvailable else { return }
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: Theme.OSD.brightnessPoll, repeats: true) { _ in
            MainActor.assumeIsolated { BrightnessSensor.shared.read() }
        }
    }

    private func stopPolling() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
    }
}

struct OSDZone: View {
    let onHover: (Bool) -> Void

    var body: some View {
        Color.black.opacity(0.01)
            .overlay(HoverTracker { inside, _ in onHover(inside) })
            .ignoresSafeArea()
    }
}
