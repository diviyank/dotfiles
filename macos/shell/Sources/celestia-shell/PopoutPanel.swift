import AppKit
import SwiftUI

enum PopoutKind { case window, volume, wifi, battery, power, mail, discord }

@MainActor
final class PopoutPanel: ObservableObject {
    @Published private(set) var kind: PopoutKind?
    @Published private(set) var revealed = false
    @Published private(set) var top: CGFloat = 0
    @Published private(set) var height: CGFloat = 0

    private let screen: NSRect
    private let model: BarModel
    private lazy var panel = ChromePanel.make(frame: .zero, clickThrough: false, content: PopoutHost(model: model, popouts: self))
    private var overItem = false
    private var overPopout = false
    private var pendingClose: DispatchWorkItem?
    private var isClosed = false

    static let fillet: CGFloat = Theme.Bar.innerRadius
    static let width: CGFloat = 240
    private static let closeDelay = 0.2
    private var anchorY: CGFloat = 0

    init(screen: NSRect, model: BarModel) {
        self.screen = screen
        self.model = model
    }

    func itemHover(_ kind: PopoutKind, rect: NSRect, inside: Bool) {
        overItem = inside
        guard inside else { return scheduleClose() }
        pendingClose?.cancel()
        show(kind: kind, anchorY: rect.midY)
    }

    func popoutHover(_ inside: Bool) {
        overPopout = inside
        if inside { pendingClose?.cancel() } else { scheduleClose() }
    }

    func refit() {
        guard let kind, revealed else { return }
        show(kind: kind, anchorY: anchorY)
    }

    func show(kind: PopoutKind, anchorY: CGFloat) {
        guard !isClosed else { return }
        self.anchorY = anchorY
        let body = NSHostingView(rootView: PopoutContent(kind: kind, model: model, popouts: self)).fittingSize
        let height = body.height + 2 * Self.fillet
        let bottom = min(max(anchorY - height / 2, screen.minY), screen.maxY - height)
        let top = screen.maxY - bottom - height
        let isMoving = panel.isVisible && revealed
        if !isMoving {
            panel.setFrame(NSRect(x: screen.minX + Theme.Bar.width, y: screen.minY, width: Self.width, height: screen.height), display: false)
            var placement = Transaction()
            placement.disablesAnimations = true
            withTransaction(placement) {
                self.top = top
                self.height = height
                self.kind = kind
            }
            panel.orderFrontRegardless()
        }
        withAnimation(Motion.enter) {
            self.top = top
            self.height = height
            self.kind = kind
            revealed = true
        }
    }

    func hide() {
        withAnimation(Motion.exit) { revealed = false }
        pendingClose = schedule(after: Motion.exitDuration) { [weak self] in
            guard let self, !self.revealed else { return }
            self.panel.orderOut(nil)
            self.kind = nil
        }
    }

    func close() {
        isClosed = true
        pendingClose?.cancel()
        panel.contentView = nil
        panel.close()
    }

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
    static let enterDuration = 0.4
    static let enter = Animation.timingCurve(0.05, 0.7, 0.1, 1, duration: enterDuration)
    static let enterCurve = CAMediaTimingFunction(controlPoints: 0.05, 0.7, 0.1, 1)
    static let exitDuration = 0.2
    static let exit = Animation.timingCurve(0.3, 0, 0.8, 0.15, duration: exitDuration)
    static let exitCurve = CAMediaTimingFunction(controlPoints: 0.3, 0, 0.8, 0.15)
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
                    .id(kind)
                    .transition(.opacity)
            }
        }
        .frame(width: PopoutPanel.width, height: popouts.height, alignment: .topLeading)
        .clipped()
        .overlay(HoverTracker { inside, _ in popouts.popoutHover(inside) })
        .offset(x: popouts.revealed ? 0 : -PopoutPanel.width, y: popouts.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
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
            case .mail: MailPopout(model: model, popouts: popouts)
            case .discord: DiscordPopout(model: model, popouts: popouts)
            }
        }
        .padding(Theme.Spacing.large)
        .frame(width: PopoutPanel.width, alignment: .leading)
    }
}
