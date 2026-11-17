import CoreGraphics
import Foundation

public enum MediaKey: Int, Sendable {
    case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
}

public struct MediaKeyEvent: Equatable, Sendable {
    public let key: MediaKey
    public let isDown: Bool
    public let isRepeat: Bool

    public init(key: MediaKey, isDown: Bool, isRepeat: Bool) {
        self.key = key
        self.isDown = isDown
        self.isRepeat = isRepeat
    }
}

private let auxControlButtonsSubtype = 8
private let keyDownState = 0xA

public func decodeMediaKey(subtype: Int, data1: Int) -> MediaKeyEvent? {
    guard subtype == auxControlButtonsSubtype, let key = MediaKey(rawValue: (data1 >> 16) & 0xFFFF) else { return nil }
    return MediaKeyEvent(key: key, isDown: (data1 & 0xFF00) >> 8 == keyDownState, isRepeat: data1 & 0x1 != 0)
}

public enum KeyStep: Equatable, Sendable { case normal, fine, passThrough }

private let shiftFlag: UInt64 = 0x20000
private let optionFlag: UInt64 = 0x80000

public func keyStep(flags: UInt64) -> KeyStep {
    switch (flags & shiftFlag != 0, flags & optionFlag != 0) {
    case (true, true): .fine
    case (false, true): .passThrough
    default: .normal
    }
}

private let coarseSteps = 16.0
private let fineSteps = 64.0
private let gridTolerance = 1e-6

public func stepLevel(_ level: Double, up: Bool, fine: Bool) -> Double {
    let steps = fine ? fineSteps : coarseSteps
    let scaled = level * steps
    let target = up ? (scaled + gridTolerance).rounded(.down) + 1 : (scaled - gridTolerance).rounded(.up) - 1
    return min(max(target / steps, 0), 1)
}

public func osdFrame(screen: CGRect, content: CGSize, border: CGFloat, fillet: CGFloat) -> CGRect {
    let height = content.height + 2 * fillet
    let centre = screen.maxY - screen.height / 4
    let y = min(max(centre - height / 2, screen.midY), screen.maxY - height)
    return CGRect(x: screen.maxX - border - content.width, y: y, width: content.width, height: height)
}

public func osdHoverZone(frame: CGRect, screen: CGRect, border: CGFloat) -> CGRect {
    let width = max(border, 2)
    return CGRect(x: screen.maxX - width, y: frame.minY, width: width, height: frame.height)
}
