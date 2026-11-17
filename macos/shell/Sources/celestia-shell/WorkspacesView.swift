import ShellCore
import SwiftUI

struct WorkspacesView: View {
    @ObservedObject var model: BarModel
    let spaces: [BarSpace]
    @Namespace private var highlight

    private static let maxIcons = 4
    private static let slide = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.4)

    var body: some View {
        VStack(spacing: Theme.Spacing.extraSmall) {
            ForEach(spaces, id: \.label) { space in
                cell(space)
            }
        }
        .padding(.vertical, Theme.Spacing.extraSmall)
        .frame(width: Theme.Bar.pillWidth)
        .background(RoundedRectangle(cornerRadius: Theme.Bar.pillWidth / 2, style: .continuous)
            .fill(model.color("surface_container")))
        .animation(Self.slide, value: spaces.first { $0.isVisible }?.label)
    }

    private func cell(_ space: BarSpace) -> some View {
        VStack(spacing: Theme.Spacing.extraSmall) {
            Text("\(space.number)")
                .font(Font(Theme.font(Theme.Family.numbers, size: Theme.TextSize.labelMedium)))
                .foregroundStyle(model.color(space.isVisible ? "on_primary" : "on_surface_variant"))
            ForEach(Self.distinctApps(space.windows), id: \.app) { window in
                if let icon = AppIcons.icon(pid: window.pid) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: Theme.Bar.spaceIcon, height: Theme.Bar.spaceIcon)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.extraSmall)
        .frame(width: Theme.Bar.cellWidth)
        .background {
            if space.isVisible {
                Capsule(style: .continuous)
                    .fill(model.color("primary"))
                    .matchedGeometryEffect(id: "visible", in: highlight)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focus(space) }
    }

    private func focus(_ space: BarSpace) {
        let label = space.label
        Task.detached { _ = runProcess(ShellPaths.yabai, ["-m", "space", "--focus", label]) }
    }

    static func distinctApps(_ windows: [BarWindow]) -> [BarWindow] {
        var seen = Set<String>()
        return windows.filter { seen.insert($0.app).inserted }.prefix(maxIcons).map { $0 }
    }
}
