import ShellCore
import SwiftUI

struct FrameShape: Shape {
    var border: CGFloat

    var animatableData: CGFloat {
        get { border }
        set { border = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let inner = CGRect(
            x: rect.minX + Theme.Bar.width,
            y: rect.minY + border,
            width: rect.width - Theme.Bar.width - border,
            height: rect.height - 2 * border
        )
        path.addRoundedRect(in: inner, cornerSize: CGSize(width: Theme.Bar.innerRadius, height: Theme.Bar.innerRadius), style: .continuous)
        return path
    }
}

struct FrameView: View {
    @ObservedObject var model: BarModel

    var body: some View {
        FrameShape(border: model.settings.border)
            .fill(model.color("surface"), style: FillStyle(eoFill: true))
            .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.4), value: model.settings.border)
            .ignoresSafeArea()
    }
}
