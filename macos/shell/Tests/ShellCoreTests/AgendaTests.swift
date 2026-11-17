import Foundation
import Testing
@testable import ShellCore

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.firstWeekday = 1
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
    paris.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false, declined: Bool = false) -> AgendaEvent {
    AgendaEvent(title: title, start: start, end: end, isAllDay: allDay, isDeclined: declined, colorHex: "#a0cfd3")
}

@Test func novemberGrid() {
    let grid = monthGrid(year: 2026, month: 11, calendar: paris)
    #expect(Array(grid.prefix(6)) == Array(repeating: nil, count: 6))
    #expect(grid.compactMap { $0 } == Array(1...30))
    #expect(grid[6] == 1)
    #expect(grid.count == 42)
}

@Test func februaryNonLeap() {
    let grid = monthGrid(year: 2027, month: 2, calendar: paris)
    #expect(grid.compactMap { $0 }.count == 28)
    #expect(grid.count % 7 == 0)
}

@Test func agendaFiltersAndOrders() {
    let now = date(17, 12)
    let events = [
        event("declined", date(17, 15), date(17, 16), declined: true),
        event("finished", date(17, 9), date(17, 10)),
        event("in progress", date(17, 11), date(17, 13)),
        event("later", date(17, 14), date(17, 15)),
        event("holiday", date(17, 0), date(18, 0), allDay: true),
        event("tomorrow", date(18, 10), date(18, 11)),
        event("after", date(19, 10), date(19, 11)),
    ]
    let result = agenda(events, now: now, calendar: paris)
    #expect(result.today.map(\.title) == ["holiday", "in progress", "later"])
    #expect(result.tomorrow.map(\.title) == ["tomorrow"])
}

@Test func agendaRollsOverAtMidnight() {
    let events = [event("standup", date(18, 10), date(18, 11))]
    let before = agenda(events, now: date(17, 23, 59), calendar: paris)
    #expect(before.today.isEmpty)
    #expect(before.tomorrow.map(\.title) == ["standup"])
    let after = agenda(events, now: date(18, 0, 1), calendar: paris)
    #expect(after.today.map(\.title) == ["standup"])
    #expect(after.tomorrow.isEmpty)
}

@Test func multiDayAllDayEvent() {
    let trip = event("trip", date(17, 0), date(20, 0), allDay: true)
    let result = agenda([trip], now: date(17, 12), calendar: paris)
    #expect(result.today.map(\.title) == ["trip"])
    #expect(result.tomorrow.map(\.title) == ["trip"])
    #expect(eventDays([trip], year: 2026, month: 11, calendar: paris) == [17, 18, 19])
}
