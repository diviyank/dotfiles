import SwiftUI

struct DashboardShape: Shape {
    let fillet: CGFloat
    let radius: CGFloat

    private static let kappa: CGFloat = 0.5523

    func path(in rect: CGRect) -> Path {
        let f = fillet, k = Self.kappa, w = rect.width, h = rect.height
        let left = f, right = w - f
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: left, y: f), control1: CGPoint(x: f * k, y: 0), control2: CGPoint(x: left, y: f - f * k))
        path.addArc(tangent1End: CGPoint(x: left, y: h), tangent2End: CGPoint(x: left + radius, y: h), radius: radius)
        path.addArc(tangent1End: CGPoint(x: right, y: h), tangent2End: CGPoint(x: right, y: h - radius), radius: radius)
        path.addLine(to: CGPoint(x: right, y: f))
        path.addCurve(to: CGPoint(x: w, y: 0), control1: CGPoint(x: right, y: f - f * k), control2: CGPoint(x: w - f * k, y: 0))
        path.closeSubpath()
        return path
    }
}
