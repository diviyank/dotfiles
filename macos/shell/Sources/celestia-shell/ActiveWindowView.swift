import ShellCore
import SwiftUI

struct ActiveWindowView: View {
    @ObservedObject var model: BarModel
    let window: BarWindow

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            if let icon = AppIcons.icon(pid: window.pid) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Theme.Bar.statusIcon, height: Theme.Bar.statusIcon)
            }
            VerticalLayout {
                Text(window.title.isEmpty ? window.app : window.title)
                    .font(Font(Theme.text(Theme.TextSize.bodySmall, weight: Theme.Bar.textWeight)))
                    .foregroundStyle(model.color("primary"))
                    .lineLimit(1)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct VerticalLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let size = child.sizeThatFits(ProposedViewSize(width: proposal.height, height: proposal.width))
        return CGSize(width: size.height, height: size.width)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
            proposal: ProposedViewSize(width: bounds.height, height: bounds.width)
        )
    }
}
