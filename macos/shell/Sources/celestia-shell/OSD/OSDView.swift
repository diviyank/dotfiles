import AppKit
import ShellCore
import SwiftUI

struct OSDHost: View {
    @ObservedObject var model: BarModel
    let panel: OSDPanel

    var body: some View {
        ZStack(alignment: .leading) {
            PopoutShape(fillet: OSDPanel.fillet, radius: Theme.Bar.innerRadius)
                .fill(model.color("surface"))
                .scaleEffect(x: -1)
            OSDSliders(model: model)
                .padding(Theme.OSD.padding)
                .padding(.trailing, OSDPanel.fillet)
                .padding(.vertical, OSDPanel.fillet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(HoverTracker { inside, _ in panel.panelHover(inside) })
        .ignoresSafeArea()
    }
}

struct OSDSliders: View {
    @ObservedObject var model: BarModel
    @ObservedObject var volume = VolumeSensor.shared
    @ObservedObject var brightness = BrightnessSensor.shared

    var body: some View {
        HStack(spacing: Theme.OSD.gap) {
            slider(
                level: volume.muted ? 0 : volume.level, role: "primary",
                glyph: volume.muted ? Glyph.volumeOff : Glyph.volumeUp,
                set: { volume.set(level: $0) },
                step: { up in volume.set(level: stepLevel(volume.level, up: up, fine: false)) }
            )
            if brightness.isAvailable {
                slider(
                    level: brightness.level, role: "secondary", glyph: Glyph.brightness6,
                    set: { brightness.set($0) },
                    step: { up in brightness.set(stepLevel(brightness.level, up: up, fine: false)) }
                )
            }
        }
    }

    private func slider(
        level: Double, role: String, glyph: String, set: @escaping (Double) -> Void, step: @escaping (Bool) -> Void
    ) -> some View {
        let clamped = min(max(level, 0), 1)
        let percent = Int((clamped * 100).rounded())
        return VStack(spacing: Theme.Spacing.small) {
            Text("\(percent)")
                .font(Font(Theme.font(Theme.Family.numbers, size: Theme.OSD.labelSize, weight: .medium)))
                .foregroundStyle(model.color("on_surface_variant"))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(percent)))
            GeometryReader { proxy in
                let knob = proxy.size.width
                ZStack(alignment: .bottom) {
                    Capsule().fill(model.color("surface_container_high"))
                    Capsule()
                        .fill(model.color(role))
                        .frame(height: knob + (proxy.size.height - knob) * clamped)
                        .overlay(alignment: .top) {
                            Text(glyph)
                                .font(Font(Theme.icon(Theme.OSD.iconSize)))
                                .foregroundStyle(model.color("on_" + role))
                                .frame(width: knob, height: knob)
                        }
                }
                .overlay(LevelCatcher(onLevel: set, onStep: step))
            }
        }
        .frame(width: Theme.OSD.sliderWidth)
        .animation(.smooth(duration: Theme.OSD.levelAnimation), value: clamped)
    }
}

struct LevelCatcher: NSViewRepresentable {
    let onLevel: (Double) -> Void
    let onStep: (Bool) -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onLevel = onLevel
        view.onStep = onStep
    }

    final class CatcherView: NSView {
        var onLevel: (Double) -> Void = { _ in }
        var onStep: (Bool) -> Void = { _ in }
        private var accumulated: CGFloat = 0
        private static let notch: CGFloat = 4

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { report(event) }
        override func mouseDragged(with event: NSEvent) { report(event) }

        override func scrollWheel(with event: NSEvent) {
            accumulated += event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / Self.notch : event.scrollingDeltaY
            while abs(accumulated) >= 1 {
                onStep(accumulated > 0)
                accumulated -= accumulated > 0 ? 1 : -1
            }
        }

        private func report(_ event: NSEvent) {
            guard bounds.height > 0 else { return }
            let knob = bounds.width
            let travel = bounds.height - knob
            guard travel > 0 else { return }
            let y = convert(event.locationInWindow, from: nil).y - knob / 2
            onLevel(Double(min(max(y / travel, 0), 1)))
        }
    }
}
