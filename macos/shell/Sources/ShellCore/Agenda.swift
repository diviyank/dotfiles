import Foundation

public struct AgendaEvent: Equatable, Sendable {
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let isDeclined: Bool
    public let colorHex: String

    public init(title: String, start: Date, end: Date, isAllDay: Bool, isDeclined: Bool, colorHex: String) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isDeclined = isDeclined
        self.colorHex = colorHex
    }

    func overlaps(_ interval: DateInterval) -> Bool {
        start < interval.end && end > interval.start
    }
}

public func monthGrid(year: Int, month: Int, calendar: Calendar) -> [Int?] {
    guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
          let days = calendar.range(of: .day, in: .month, for: first)?.count
    else { return [] }
    let mondayFirstOffset = (calendar.component(.weekday, from: first) + 5) % 7
    var grid: [Int?] = Array(repeating: nil, count: mondayFirstOffset) + (1...days).map { $0 }
    grid += Array(repeating: nil, count: (7 - grid.count % 7) % 7)
    return grid
}

public func agenda(_ events: [AgendaEvent], now: Date, calendar: Calendar) -> (today: [AgendaEvent], tomorrow: [AgendaEvent]) {
    let today = dayInterval(containing: now, calendar: calendar)
    let tomorrow = dayInterval(containing: today.end, calendar: calendar)
    let accepted = events.filter { !$0.isDeclined }
    let todays = accepted.filter { $0.overlaps(today) && $0.end > now }
    let tomorrows = accepted.filter { $0.overlaps(tomorrow) }
    return (ordered(todays), ordered(tomorrows))
}

public func eventDays(_ events: [AgendaEvent], year: Int, month: Int, calendar: Calendar) -> Set<Int> {
    let accepted = events.filter { !$0.isDeclined }
    let days = monthGrid(year: year, month: month, calendar: calendar).compactMap { $0 }
    return Set(days.filter { day in
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        let interval = dayInterval(containing: date, calendar: calendar)
        return accepted.contains { $0.overlaps(interval) }
    })
}

public func eventFetchIntervals(year: Int, month: Int, now: Date, calendar: Calendar) -> [DateInterval] {
    let today = calendar.startOfDay(for: now)
    guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
          let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
          let agendaEnd = calendar.date(byAdding: .day, value: 2, to: today)
    else { return [] }
    let shownMonth = DateInterval(start: monthStart, end: monthEnd)
    let upcoming = DateInterval(start: today, end: agendaEnd)
    guard shownMonth.start <= upcoming.end, upcoming.start <= shownMonth.end else { return [shownMonth, upcoming] }
    return [DateInterval(start: min(shownMonth.start, upcoming.start), end: max(shownMonth.end, upcoming.end))]
}

private func dayInterval(containing date: Date, calendar: Calendar) -> DateInterval {
    calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
}

private func ordered(_ events: [AgendaEvent]) -> [AgendaEvent] {
    events.sorted { lhs, rhs in
        lhs.isAllDay != rhs.isAllDay ? lhs.isAllDay : lhs.start < rhs.start
    }
}
