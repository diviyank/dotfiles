import SwiftUI

struct ClockView: View {
    @ObservedObject var model: BarModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(Self.twoDigits(.hour, of: context.date))
                Text(Self.twoDigits(.minute, of: context.date))
            }
            .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Bar.clockSize, weight: .medium)))
            .foregroundStyle(model.color("tertiary"))
            .monospacedDigit()
        }
    }

    private static func twoDigits(_ component: Calendar.Component, of date: Date) -> String {
        String(format: "%02d", Calendar.current.component(component, from: date))
    }
}
