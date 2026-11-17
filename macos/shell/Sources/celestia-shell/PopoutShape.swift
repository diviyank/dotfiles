import SwiftUI

struct PopoutShape: Shape {
    let fillet: CGFloat
    let radius: CGFloat

    private static let kappa: CGFloat = 0.5523

    func path(in rect: CGRect) -> Path {
        let f = fillet, k = Self.kappa, w = rect.width, h = rect.height
        let top = f, bottom = h - f
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: f, y: top), control1: CGPoint(x: 0, y: f * k), control2: CGPoint(x: f - f * k, y: top))
        path.addArc(tangent1End: CGPoint(x: w, y: top), tangent2End: CGPoint(x: w, y: top + radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: w, y: bottom), tangent2End: CGPoint(x: w - radius, y: bottom), radius: radius)
        path.addLine(to: CGPoint(x: f, y: bottom))
        path.addCurve(to: CGPoint(x: 0, y: h), control1: CGPoint(x: f - f * k, y: bottom), control2: CGPoint(x: 0, y: h - f * k))
        path.closeSubpath()
        return path
    }
}
