import ShellCore
import SwiftUI

struct BarView: View {
    @ObservedObject var model: BarModel
    let uuid: String

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            if let display = model.display(uuid: uuid) {
                WorkspacesView(model: model, spaces: display.spaces)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.small)
        .frame(width: Theme.Bar.width)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
