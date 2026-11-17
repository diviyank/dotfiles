import SwiftUI

struct WiFiPopout: View {
    @ObservedObject var model: BarModel
    @ObservedObject private var wifi = WiFiSensor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            model.title(wifi.ssid ?? "Wi-Fi")
            model.detail(wifi.rssi.map { "Signal \($0) dBm" } ?? "Disconnected")
        }
    }
}
