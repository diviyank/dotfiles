import ShellCore
import SwiftUI

struct WindowTitlePopout: View {
    @ObservedObject var model: BarModel

    var body: some View {
        if let window = focusedWindow(model.displays) {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                model.detail(window.app, role: "outline")
                model.title(window.title.isEmpty ? window.app : window.title)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
