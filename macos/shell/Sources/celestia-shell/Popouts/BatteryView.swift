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
            model.detail(state)
        }
    }

    private var state: String {
        let remaining = battery.minutesRemaining.map { String(format: "%d:%02d", $0 / 60, $0 % 60) }
        switch (battery.charging, remaining) {
        case (true, let time?): return "Charging, full in \(time)"
        case (true, nil): return "Charging"
        case (false, let time?): return "\(time) remaining"
        case (false, nil): return "On battery"
        }
    }
}
