import CoreGraphics
import Testing
@testable import ShellCore

@Test func hoverZoneDefault() {
    let zone = hoverZone(screen: CGRect(x: 0, y: 0, width: 1920, height: 1200), width: 760, border: 6)
    #expect(zone == CGRect(x: 580, y: 1194, width: 760, height: 4))
}

@Test func hoverZoneWithZeroBorder() {
    let zone = hoverZone(screen: CGRect(x: 0, y: 0, width: 1920, height: 1200), width: 760, border: 0)
    #expect(zone == CGRect(x: 580, y: 1196, width: 760, height: 2))
}

@Test func hoverZoneOffsetScreen() {
    let zone = hoverZone(screen: CGRect(x: 1920, y: 123, width: 1710, height: 1112), width: 760, border: 6)
    #expect(zone.minX == CGFloat(2395))
    #expect(zone.maxY == CGFloat(1233))
}

@Test func dashboardFrameWithNotchInset() {
    let inset = dashboardTopInset(border: 6, safeAreaTop: 32)
    #expect(inset == 32)
    let frame = dashboardFrame(screen: CGRect(x: 0, y: 0, width: 1920, height: 1200), content: CGSize(width: 760, height: 300), topInset: inset, fillet: 21)
    #expect(frame == CGRect(x: 559, y: 868, width: 802, height: 332))
}

@Test func dashboardTopInsetWithoutNotch() {
    #expect(dashboardTopInset(border: 6, safeAreaTop: 0) == 6)
}

@Test func hoverZoneCoversNotchHeight() {
    let zone = hoverZone(screen: CGRect(x: 0, y: 0, width: 1470, height: 956), width: 760, border: 6, safeAreaTop: 32)
    #expect(zone == CGRect(x: 355, y: 924, width: 760, height: 30))
}
