import ShellCore
import SwiftUI

struct DashboardView: View {
    let panel: DashboardPanel
    @ObservedObject var model: BarModel
    let data: DashboardModel

    var body: some View {
        VStack(spacing: Theme.Dashboard.gap) {
            HStack(spacing: Theme.Dashboard.gap) {
                ClockWeatherCard(model: model, weather: data.weather)
                    .frame(width: Theme.Dashboard.clockWidth)
                CalendarCard(model: model, store: data.calendar)
                    .frame(width: Theme.Dashboard.calendarWidth)
                EventsCard(model: model, store: data.calendar)
                    .overlay(alignment: .topTrailing) { settingsButton }
            }
            .frame(height: Theme.Dashboard.topRowHeight)
            HStack(spacing: Theme.Dashboard.gap) {
                MediaCard(model: model, spotify: data.spotify)
                    .frame(width: Theme.Dashboard.clockWidth + Theme.Dashboard.calendarWidth / 2)
                PerformanceCard(model: model, sampler: data.performance)
            }
            .frame(height: Theme.Dashboard.bottomRowHeight)
        }
        .padding(Theme.Dashboard.padding)
        .frame(width: Theme.Dashboard.width, height: Theme.Dashboard.height)
    }

    private var settingsButton: some View {
        Text(Glyph.settings)
            .font(Font(Theme.icon(Theme.Dashboard.gearSize)))
            .foregroundStyle(model.color("on_surface_variant"))
            .contentShape(Rectangle())
            .onTapGesture { panel.openSystemSettings() }
            .padding(Theme.Spacing.small)
    }
}

struct DashboardCard<Content: View>: View {
    @ObservedObject var model: BarModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, Theme.Spacing.medium)
            .padding(.horizontal, Theme.Dashboard.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(model.color("surface_container"), in: RoundedRectangle(cornerRadius: Theme.Dashboard.cardRadius))
    }
}
