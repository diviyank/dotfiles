import CoreGraphics
import Foundation

@MainActor
final class BrightnessSensor: ObservableObject {
    static let shared = BrightnessSensor()

    @Published private(set) var level: Double = 0
    var isAvailable: Bool { display != nil && getBrightness != nil && setBrightness != nil }

    private typealias Getter = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private static let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    private let getBrightness: Getter?
    private let setBrightness: Setter?
    private let display = BrightnessSensor.builtInDisplay()

    private init() {
        let handle = dlopen(Self.frameworkPath, RTLD_LAZY)
        getBrightness = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: Getter.self) }
        setBrightness = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: Setter.self) }
        read()
    }

    func read() {
        guard let display, let getBrightness else { return }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return }
        level = Double(value)
    }

    func set(_ level: Double) {
        guard let display, let setBrightness else { return }
        let clamped = min(max(level, 0), 1)
        guard setBrightness(display, Float(clamped)) == 0 else { return }
        self.level = clamped
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
