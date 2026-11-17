import ShellCore
import SwiftUI

struct ClockWeatherCard: View {
    @ObservedObject var model: BarModel
    @ObservedObject var weather: WeatherService

    var body: some View {
        DashboardCard(model: model) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    Text("\(ClockView.twoDigits(.hour, of: context.date)):\(ClockView.twoDigits(.minute, of: context.date))")
                        .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.clockSize, weight: .medium)))
                        .foregroundStyle(model.color("tertiary"))
                        .monospacedDigit()
                    Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(Font(Theme.text(Theme.Dashboard.smallText)))
                        .foregroundStyle(model.color("on_surface_variant"))
                    Spacer(minLength: 0)
                    weatherRow(now: context.date)
                }
            }
        }
    }

    @ViewBuilder
    private func weatherRow(now: Date) -> some View {
        if let reading = weather.cache?.reading {
            let look = weatherLook(code: reading.code)
            HStack(spacing: Theme.Spacing.small) {
                Text(look.glyph)
                    .font(Font(Theme.icon(Theme.Dashboard.weatherIcon)))
                    .foregroundStyle(model.color("primary"))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Int(reading.temperature.rounded()))°")
                        .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.temperatureSize)))
                        .foregroundStyle(model.color("on_surface"))
                    Text(caption(look.text, reading: reading, now: now))
                        .font(Font(Theme.text(Theme.Dashboard.tinyText)))
                        .foregroundStyle(model.color("on_surface_variant"))
                        .lineLimit(2)
                }
            }
        } else if weather.failed {
            Text("Weather unavailable")
                .font(Font(Theme.text(Theme.Dashboard.tinyText)))
                .foregroundStyle(model.color("on_surface_variant"))
        }
    }

    private func caption(_ condition: String, reading: WeatherReading, now: Date) -> String {
        let place = weather.cache?.coordinates?.name ?? model.settings.weatherLocation
        let base = "\(place), \(condition.lowercased())"
        return weather.failed ? "\(base) · \(ageText(since: reading.fetchedAt, now: now))" : base
    }
}
