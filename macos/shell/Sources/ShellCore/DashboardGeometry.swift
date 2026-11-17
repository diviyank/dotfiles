import CoreGraphics

public func hoverZone(screen: CGRect, width: CGFloat, border: CGFloat, menuBarGap: CGFloat = 2) -> CGRect {
    let height = max(border - menuBarGap, 2)
    return CGRect(x: screen.midX - width / 2, y: screen.maxY - menuBarGap - height, width: width, height: height)
}

public func dashboardTopInset(border: CGFloat, safeAreaTop: CGFloat) -> CGFloat {
    max(border, safeAreaTop)
}

public func dashboardFrame(screen: CGRect, content: CGSize, topInset: CGFloat, fillet: CGFloat) -> CGRect {
    let width = content.width + 2 * fillet
    let height = content.height + topInset
    return CGRect(x: screen.midX - width / 2, y: screen.maxY - height, width: width, height: height)
}
