import ShellCore
import SwiftUI

struct EventsCard: View {
    @ObservedObject var model: BarModel
    @ObservedObject var store: CalendarStore

    private static let todayLimit = 3
    private static let tomorrowLimit = 2
    private static let dayLimit = 5

    var body: some View {
        DashboardCard(model: model) {
            switch store.access {
            case .denied: denied
            case .unknown: Color.clear
            case .granted: lists
            }
        }
    }

    @ViewBuilder private var lists: some View {
        if let day = store.selectedDay {
            section(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased(),
                    eventsOn(day, store.events, calendar: .current), limit: Self.dayLimit)
        } else {
            let lists = agenda(store.events, now: store.now, calendar: .current)
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                section("TODAY", lists.today, limit: Self.todayLimit)
                section("TOMORROW", lists.tomorrow, limit: Self.tomorrowLimit)
                    .padding(.top, Theme.Spacing.extraSmall)
            }
        }
    }

    private func section(_ title: String, _ events: [AgendaEvent], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
            Text(title)
                .font(Font(Theme.text(Theme.Dashboard.tinyText, weight: .medium)))
                .foregroundStyle(model.color("outline"))
            if events.isEmpty {
                muted("No events")
            }
            ForEach(Array(events.prefix(limit).enumerated()), id: \.offset) { _, event in
                row(event)
            }
            if events.count > limit {
                muted("+\(events.count - limit) more")
            }
        }
    }

    private func row(_ event: AgendaEvent) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.colorHex) ?? model.color("tertiary"))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Theme.Spacing.extraSmall) {
                    Text(event.title)
                        .font(Font(Theme.text(Theme.Dashboard.smallText)))
                        .foregroundStyle(model.color("on_surface"))
                        .lineLimit(1)
                    if event.meetingURL != nil {
                        Text(Glyph.videocam)
                            .font(Font(Theme.icon(Theme.Dashboard.smallText)))
                            .foregroundStyle(model.color("primary"))
                    }
                }
                Text(timeRange(event))
                    .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.tinyText)))
                    .foregroundStyle(model.color("on_surface_variant"))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture { store.open(event) }
    }

    private func muted(_ text: String) -> some View {
        Text(text)
            .font(Font(Theme.text(Theme.Dashboard.tinyText)))
            .foregroundStyle(model.color("on_surface_variant"))
    }

    private var denied: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            muted("Calendar access is off")
            Text("Open Privacy settings")
                .font(Font(Theme.text(Theme.Dashboard.smallText, weight: .medium)))
                .foregroundStyle(model.color("on_primary"))
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.vertical, Theme.Spacing.extraSmall)
                .background(model.color("primary"), in: Capsule())
                .onTapGesture(perform: store.openPrivacySettings)
        }
    }

    private func timeRange(_ event: AgendaEvent) -> String {
        guard !event.isAllDay else { return "All day" }
        return "\(clock(event.start)) – \(clock(event.end))"
    }

    private func clock(_ date: Date) -> String {
        "\(ClockView.twoDigits(.hour, of: date)):\(ClockView.twoDigits(.minute, of: date))"
    }
}

extension Color {
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
