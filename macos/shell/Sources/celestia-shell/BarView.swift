import ShellCore
import SwiftUI

struct BarView: View {
    @ObservedObject var model: BarModel
    let uuid: String

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            Text(Glyph.logo)
                .font(Font(Theme.icon(Theme.IconSize.medium)))
                .foregroundStyle(model.color("primary"))
                .contentShape(Rectangle())
                .onTapGesture {
                    DistributedNotificationCenter.default().postNotificationName(
                        launcherToggleNotification, object: nil, deliverImmediately: true)
                }
            if let display = model.display(uuid: uuid) {
                WorkspacesView(model: model, spaces: display.spaces)
            }
            if let window = focusedWindow(model.displays) {
                ActiveWindowView(model: model, window: window)
                    .layoutPriority(-1)
            }
            Spacer(minLength: Theme.Spacing.large)
            ClockView(model: model)
        }
        .padding(.vertical, Theme.Spacing.small)
        .frame(width: Theme.Bar.width)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
