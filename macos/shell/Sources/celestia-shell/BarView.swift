import ShellCore
import SwiftUI

struct BarView: View {
    @ObservedObject var model: BarModel
    let uuid: String

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            Spacer(minLength: 0)
        }
        .frame(width: Theme.Bar.width)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
