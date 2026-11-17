import CoreWLAN
import Foundation

@MainActor
final class WiFiSensor: ObservableObject {
    static let shared = WiFiSensor()

    @Published private(set) var rssi: Int?
    @Published private(set) var ssid: String?

    private var timer: Timer?

    private init() {
        read()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { WiFiSensor.shared.read() }
        }
        timer?.tolerance = 5
    }

    private func read() {
        let interface = CWWiFiClient.shared().interface()
        let signal = interface?.rssiValue() ?? 0
        rssi = signal == 0 ? nil : signal
        ssid = interface?.ssid()
    }
}
