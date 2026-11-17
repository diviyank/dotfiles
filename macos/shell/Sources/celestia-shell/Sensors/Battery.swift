import Foundation
import IOKit.ps

@MainActor
final class BatterySensor: ObservableObject {
    static let shared = BatterySensor()

    @Published private(set) var present = false
    @Published private(set) var percent = 0
    @Published private(set) var charging = false
    @Published private(set) var minutesRemaining: Int?

    private init() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let sensor = Unmanaged<BatterySensor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { sensor.read() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        read()
    }

    private func read() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let battery = sources.lazy
                .compactMap({ IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] })
                .first(where: { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType })
        else {
            present = false
            return
        }
        present = true
        let current = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = max(battery[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
        percent = current * 100 / maximum
        charging = battery[kIOPSIsChargingKey] as? Bool ?? false
        let minutes = battery[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int ?? -1
        minutesRemaining = minutes > 0 ? minutes : nil
    }
}
