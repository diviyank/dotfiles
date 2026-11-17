import SwiftUI

struct ClockWeatherCard: View {
    @ObservedObject var model: BarModel

    var body: some View {
        DashboardCard(model: model) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    Text("\(ClockView.twoDigits(.hour, of: context.date)):\(ClockView.twoDigits(.minute, of: context.date))")
                        .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.clockSize, weight: .medium)))
                        .foregroundStyle(model.color("tertiary"))
                        .monospacedDigit()
                    Text(Self.dateText(context.date))
                        .font(Font(Theme.text(Theme.Dashboard.smallText)))
                        .foregroundStyle(model.color("on_surface_variant"))
                }
            }
        }
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
