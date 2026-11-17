import ShellCore
import SwiftUI

struct CalendarCard: View {
    @ObservedObject var model: BarModel
    @ObservedObject var store: CalendarStore

    var body: some View {
        DashboardCard(model: model) {
            VStack(spacing: Theme.Spacing.extraSmall) {
                header
                grid
            }
        }
    }

    private var header: some View {
        HStack {
            arrow(Glyph.chevronLeft, action: store.showPrevious)
            Spacer()
            Text(monthTitle)
                .font(Font(Theme.text(Theme.Dashboard.smallText, weight: .medium)))
                .foregroundStyle(model.color("on_surface"))
                .onTapGesture(perform: store.showToday)
            Spacer()
            arrow(Glyph.chevronRight, action: store.showNext)
        }
    }

    private func arrow(_ glyph: String, action: @escaping () -> Void) -> some View {
        Text(glyph)
            .font(Font(Theme.icon(Theme.Dashboard.gearSize)))
            .foregroundStyle(model.color("on_surface_variant"))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var grid: some View {
        let calendar = Calendar.current
        let days = monthGrid(year: store.shown.year, month: store.shown.month, calendar: calendar)
        let marked = eventDays(store.events, year: store.shown.year, month: store.shown.month, calendar: calendar)
        let today = MonthRef.containing(store.now) == store.shown ? calendar.component(.day, from: store.now) : nil
        let selected = store.selectedDay.map { calendar.component(.day, from: $0) }
        let columns = Array(repeating: GridItem(.fixed(Theme.Dashboard.dayCell), spacing: 2), count: 7)
        return VStack(spacing: 1) {
            LazyVGrid(columns: columns) {
                ForEach(Array(Self.weekdayInitials(calendar).enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(Font(Theme.text(Theme.Dashboard.tinyText, weight: .medium)))
                        .foregroundStyle(model.color("outline"))
                }
            }
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day, isToday: day != nil && day == today, isSelected: day != nil && day == selected, hasEvents: day.map(marked.contains) ?? false)
                }
            }
        }
    }

    private func dayCell(_ day: Int?, isToday: Bool, isSelected: Bool, hasEvents: Bool) -> some View {
        Text(day.map(String.init) ?? "")
            .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.tinyText)))
            .foregroundStyle(model.color(isToday ? "on_primary" : "on_surface_variant"))
            .frame(width: Theme.Dashboard.dayCell, height: Theme.Dashboard.dayCell - 4)
            .background {
                if isToday {
                    Capsule().fill(model.color("primary"))
                } else if isSelected {
                    Capsule().strokeBorder(model.color("primary"), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if let day { store.select(day: day) } }
            .overlay(alignment: .bottom) {
                if hasEvents && !isToday {
                    Circle().fill(model.color("tertiary")).frame(width: 3, height: 3).offset(y: 2)
                }
            }
    }

    private var monthTitle: String {
        let date = Calendar.current.date(from: DateComponents(year: store.shown.year, month: store.shown.month, day: 1)) ?? store.now
        return date.formatted(.dateTime.month(.wide).year())
    }

    private static func weekdayInitials(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...] + symbols[..<1])
    }
}
