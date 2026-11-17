import AppKit
import SwiftUI

struct HoverTracker: NSViewRepresentable {
    let onHover: (Bool, NSRect) -> Void

    func makeNSView(context: Context) -> TrackerView { TrackerView() }

    func updateNSView(_ view: TrackerView, context: Context) {
        view.onHover = onHover
    }

    final class TrackerView: NSView {
        var onHover: (Bool, NSRect) -> Void = { _, _ in }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) { onHover(true, screenRect) }
        override func mouseExited(with event: NSEvent) { onHover(false, screenRect) }

        private var screenRect: NSRect {
            window?.convertToScreen(convert(bounds, to: nil)) ?? .zero
        }
    }
}

extension View {
    func popout(_ kind: PopoutKind, _ popouts: PopoutPanel) -> some View {
        overlay(HoverTracker { inside, rect in popouts.itemHover(kind, rect: rect, inside: inside) })
    }
}
