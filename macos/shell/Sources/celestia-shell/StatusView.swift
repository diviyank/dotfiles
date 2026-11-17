import AppKit
import ShellCore
import SwiftUI

struct StatusView: View {
    @ObservedObject var model: BarModel
    let popouts: PopoutPanel
    @ObservedObject private var volume = VolumeSensor.shared
    @ObservedObject private var battery = BatterySensor.shared
    @ObservedObject private var wifi = WiFiSensor.shared
    @ObservedObject private var badges = BadgeSensor.shared

    private static let volumeStep = 5

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            if let count = badges.mail {
                badged(Glyph.mail, count: count) { focus("seven") }
            }
            if let count = badges.discord {
                badged(Glyph.forum, count: count) { focus("six") }
            }
            icon(volumeGlyph(percent: volume.percent, muted: volume.muted), role: "primary")
                .overlay(ScrollCatcher(
                    onScroll: { up in volume.set(percent: volume.percent + (up ? 1 : -1) * Self.volumeStep) },
                    onClick: { volume.toggleMute() }
                ))
                .popout(.volume, popouts)
            icon(wifiGlyph(rssi: wifi.rssi))
                .popout(.wifi, popouts)
            if battery.present {
                icon(batteryGlyph(percent: battery.percent, charging: battery.charging))
                    .popout(.battery, popouts)
            }
        }
        .padding(.vertical, Theme.Spacing.small)
        .frame(width: Theme.Bar.pillWidth)
        .background(RoundedRectangle(cornerRadius: Theme.Bar.pillWidth / 2, style: .continuous)
            .fill(model.color("surface_container")))
    }

    private func icon(_ glyph: String, role: String = "on_surface_variant") -> some View {
        Text(glyph)
            .font(Font(Theme.icon(Theme.Bar.statusIcon)))
            .foregroundStyle(model.color(role))
    }

    private func badged(_ glyph: String, count: String, action: @escaping () -> Void) -> some View {
        icon(glyph)
            .overlay(alignment: .topTrailing) {
                Text(count)
                    .font(Font(Theme.font(Theme.Family.numbers, size: 9, weight: .semibold)))
                    .foregroundStyle(model.color("on_error"))
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(model.color("error")))
                    .offset(x: 6, y: -5)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private func focus(_ label: String) {
        Task.detached { _ = runProcess(ShellPaths.yabai, ["-m", "space", "--focus", label]) }
    }
}

struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (Bool) -> Void
    let onClick: () -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onScroll = onScroll
        view.onClick = onClick
    }

    final class CatcherView: NSView {
        var onScroll: (Bool) -> Void = { _ in }
        var onClick: () -> Void = {}
        private var accumulated: CGFloat = 0
        private static let notch: CGFloat = 4

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) { onClick() }

        override func scrollWheel(with event: NSEvent) {
            accumulated += event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / Self.notch : event.scrollingDeltaY
            while abs(accumulated) >= 1 {
                onScroll(accumulated > 0)
                accumulated -= accumulated > 0 ? 1 : -1
            }
        }
    }
}
