import AppKit
import SwiftUI

enum PopoutKind { case window, volume, wifi, battery, power }

@MainActor
final class PopoutPanel: ObservableObject {
    @Published private(set) var kind: PopoutKind?
    @Published private(set) var revealed = false

    private let screen: NSRect
    private let model: BarModel
    private lazy var panel = ChromePanel.make(frame: .zero, clickThrough: false, content: PopoutHost(model: model, popouts: self))
    private var overItem = false
    private var overPopout = false
    private var pendingOpen: DispatchWorkItem?
    private var pendingClose: DispatchWorkItem?

    static let fillet: CGFloat = Theme.Bar.innerRadius
    static let width: CGFloat = 240
    private static let openDelay = 0.15
    private static let closeDelay = 0.2

    init(screen: NSRect, model: BarModel) {
        self.screen = screen
        self.model = model
    }

    func itemHover(_ kind: PopoutKind, rect: NSRect, inside: Bool) {
        overItem = inside
        pendingOpen?.cancel()
        guard inside else { return scheduleClose() }
        pendingClose?.cancel()
        if panel.isVisible && revealed {
            show(kind: kind, anchorY: rect.midY)
        } else {
            pendingOpen = schedule(after: Self.openDelay) { [weak self] in self?.show(kind: kind, anchorY: rect.midY) }
        }
    }

    func popoutHover(_ inside: Bool) {
        overPopout = inside
        if inside { pendingClose?.cancel() } else { scheduleClose() }
    }

    func show(kind: PopoutKind, anchorY: CGFloat) {
        let body = NSHostingView(rootView: PopoutContent(kind: kind, model: model, popouts: self)).fittingSize
        let height = body.height + 2 * Self.fillet
        let y = min(max(anchorY - height / 2, screen.minY), screen.maxY - height)
        panel.setFrame(NSRect(x: screen.minX + Theme.Bar.width, y: y, width: Self.width, height: height), display: true)
        self.kind = kind
        panel.orderFrontRegardless()
        withAnimation(Motion.emphasized) { revealed = true }
    }

    func hide() {
        pendingOpen?.cancel()
        withAnimation(Motion.emphasized) { revealed = false }
        pendingClose = schedule(after: Motion.fadeDuration) { [weak self] in
            guard let self, !self.revealed else { return }
            self.panel.orderOut(nil)
            self.kind = nil
        }
    }

    func close() { panel.close() }

    private func scheduleClose() {
        pendingClose?.cancel()
        pendingClose = schedule(after: Self.closeDelay) { [weak self] in
            guard let self, !self.overItem, !self.overPopout else { return }
            self.hide()
        }
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) -> DispatchWorkItem {
        let item = DispatchWorkItem { MainActor.assumeIsolated(work) }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }
}

enum Motion {
    static let emphasized = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.4)
    static let fadeDuration = 0.2
    static let fade = Animation.easeOut(duration: fadeDuration)
}

struct PopoutHost: View {
    @ObservedObject var model: BarModel
    @ObservedObject var popouts: PopoutPanel

    var body: some View {
        ZStack(alignment: .topLeading) {
            PopoutShape(fillet: PopoutPanel.fillet, radius: Theme.Bar.innerRadius)
                .fill(model.color("surface"))
            if let kind = popouts.kind {
                PopoutContent(kind: kind, model: model, popouts: popouts)
                    .padding(.vertical, PopoutPanel.fillet)
                    .opacity(popouts.revealed ? 1 : 0)
                    .animation(Motion.fade, value: popouts.revealed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mask(alignment: .leading) {
            Rectangle().scaleEffect(x: popouts.revealed ? 1 : 0.001, anchor: .leading)
        }
        .overlay(HoverTracker { inside, _ in popouts.popoutHover(inside) })
        .ignoresSafeArea()
    }
}

struct PopoutContent: View {
    let kind: PopoutKind
    @ObservedObject var model: BarModel
    let popouts: PopoutPanel

    var body: some View {
        Group {
            switch kind {
            case .window: WindowTitlePopout(model: model)
            case .volume: VolumePopout(model: model)
            case .wifi: WiFiPopout(model: model)
            case .battery: BatteryPopout(model: model)
            case .power: PowerPopout(model: model, popouts: popouts)
            }
        }
        .padding(Theme.Spacing.large)
        .frame(width: PopoutPanel.width, alignment: .leading)
    }
}
