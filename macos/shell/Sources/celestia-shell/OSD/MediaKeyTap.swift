import AppKit
import ApplicationServices
import ShellCore

@MainActor
final class MediaKeyTap {
    private let onKey: (MediaKey, KeyStep) -> Void
    private var tap: CFMachPort?
    private var trustTimer: Timer?

    private static let systemDefinedMask = CGEventMask(1 << 14)
    private static let trustRetry: TimeInterval = 5

    init(onKey: @escaping (MediaKey, KeyStep) -> Void) {
        self.onKey = onKey
    }

    func start() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
            installTap()
        } else {
            trustTimer = Timer.scheduledTimer(withTimeInterval: Self.trustRetry, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard AXIsProcessTrusted() else { return }
                    self?.trustTimer?.invalidate()
                    self?.trustTimer = nil
                    self?.installTap()
                }
            }
        }
    }

    private func installTap() {
        guard tap == nil,
              let tap = CGEvent.tapCreate(
                  tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                  eventsOfInterest: Self.systemDefinedMask, callback: mediaKeyCallback,
                  userInfo: Unmanaged.passUnretained(self).toOpaque()
              )
        else { return }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }
        guard let nsEvent = NSEvent(cgEvent: event),
              let media = decodeMediaKey(subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1)
        else { return event }
        let step = keyStep(flags: event.flags.rawValue)
        let isBrightness = media.key == .brightnessUp || media.key == .brightnessDown
        if step == .passThrough || (isBrightness && !BrightnessSensor.shared.isAvailable) { return event }
        if media.isDown { onKey(media.key, step) }
        return nil
    }
}

private func mediaKeyCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
    let result = MainActor.assumeIsolated { tap.handle(type, event) }
    return result.map { Unmanaged.passUnretained($0) }
}
