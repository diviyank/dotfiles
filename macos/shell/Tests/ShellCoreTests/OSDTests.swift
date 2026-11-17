import CoreGraphics
import Testing
@testable import ShellCore

@Test func decodeMediaKeyDown() {
    #expect(decodeMediaKey(subtype: 8, data1: (0 << 16) | (0xA << 8)) == MediaKeyEvent(key: .soundUp, isDown: true, isRepeat: false))
    #expect(decodeMediaKey(subtype: 8, data1: (7 << 16) | (0xB << 8)) == MediaKeyEvent(key: .mute, isDown: false, isRepeat: false))
}

@Test func decodeMediaKeyRepeat() {
    #expect(decodeMediaKey(subtype: 8, data1: (3 << 16) | (0xA << 8) | 1)?.isRepeat == true)
}

@Test func decodeMediaKeyIgnoresOthers() {
    #expect(decodeMediaKey(subtype: 8, data1: (16 << 16) | (0xA << 8)) == nil)
    #expect(decodeMediaKey(subtype: 7, data1: (0 << 16) | (0xA << 8)) == nil)
}

@Test func keyStepModifiers() {
    #expect(keyStep(flags: 0) == .normal)
    #expect(keyStep(flags: 0x20000 | 0x80000) == .fine)
    #expect(keyStep(flags: 0x80000) == .passThrough)
    #expect(keyStep(flags: 0x20000) == .normal)
}

@Test func stepLevelOnGrid() {
    #expect(stepLevel(0.5, up: true, fine: false) == 0.5625)
    #expect(stepLevel(0.5, up: false, fine: true) == 0.484375)
    #expect(stepLevel(1, up: true, fine: false) == 1)
    #expect(stepLevel(0, up: false, fine: false) == 0)
}

@Test func stepLevelSnapsOffGrid() {
    #expect(stepLevel(0.30, up: true, fine: false) == 0.3125)
    #expect(stepLevel(0.30, up: false, fine: false) == 0.25)
}

@Test func osdFrameTopHalfOfRightBorder() {
    let frame = osdFrame(screen: CGRect(x: 0, y: 0, width: 1470, height: 956), content: CGSize(width: 88, height: 200), border: 6, fillet: 21)
    #expect(frame == CGRect(x: 1376, y: 596, width: 88, height: 242))
}

@Test func osdHoverZoneStaysInTopHalf() {
    let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
    let frame = osdFrame(screen: screen, content: CGSize(width: 88, height: 200), border: 6, fillet: 21)
    let zone = osdHoverZone(frame: frame, screen: screen, border: 6)
    #expect(zone == CGRect(x: 1464, y: 596, width: 6, height: 242))
    #expect(zone.minY >= screen.midY)
}
