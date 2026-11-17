import SwiftUI

extension BarModel {
    func title(_ text: String) -> some View {
        Text(text).font(Font(Theme.text(Theme.TextSize.bodyMedium, weight: .medium))).foregroundStyle(color("on_surface"))
    }

    func detail(_ text: String, role: String = "on_surface_variant") -> some View {
        Text(text).font(Font(Theme.text(Theme.TextSize.bodySmall))).foregroundStyle(color(role))
    }

    func number(_ text: String) -> some View {
        Text(text).font(Font(Theme.font(Theme.Family.numbers, size: Theme.TextSize.bodySmall, weight: .medium)))
            .foregroundStyle(color("primary"))
    }
}
