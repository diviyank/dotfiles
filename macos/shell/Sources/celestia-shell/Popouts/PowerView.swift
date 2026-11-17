import ShellCore
import SwiftUI

struct PowerPopout: View {
    @ObservedObject var model: BarModel
    let popouts: PopoutPanel

    private static let rows: [(glyph: String, label: String, action: () -> Void)] = [
        (Glyph.lock, "Lock", PowerActions.lock),
        (Glyph.sleep, "Sleep", PowerActions.sleep),
        (Glyph.restart, "Restart", PowerActions.restart),
        (Glyph.power, "Shut down", PowerActions.shutDown),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            ForEach(Self.rows, id: \.label) { row in
                PowerRow(model: model, glyph: row.glyph, label: row.label) {
                    popouts.hide()
                    row.action()
                }
            }
        }
    }
}

private struct PowerRow: View {
    @ObservedObject var model: BarModel
    let glyph: String
    let label: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Text(glyph).font(Font(Theme.icon(Theme.Bar.statusIcon))).foregroundStyle(model.color("primary"))
            model.detail(label, role: "on_surface")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.small)
        .padding(.vertical, Theme.Spacing.small)
        .background(RoundedRectangle(cornerRadius: Theme.Rounding.large, style: .continuous)
            .fill(model.color("on_surface", opacity: hovered ? Double(Theme.Launcher.highlightAlpha) : 0)))
        .contentShape(Rectangle())
        .overlay(HoverTracker { inside, _ in hovered = inside })
        .onTapGesture(perform: action)
    }
}
