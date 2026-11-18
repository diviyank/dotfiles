import ShellCore
import SwiftUI

struct BatteryPopout: View {
    @ObservedObject var model: BarModel
    @ObservedObject private var battery = BatterySensor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            HStack {
                model.title("Battery")
                Spacer()
                model.number("\(battery.percent)%")
            }
            model.detail(batteryState(
                charging: battery.charging, pluggedIn: battery.pluggedIn, minutesRemaining: battery.minutesRemaining
            ))
        }
    }
}
