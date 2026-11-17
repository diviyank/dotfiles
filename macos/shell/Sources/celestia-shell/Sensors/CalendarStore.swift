import AppKit
import EventKit
import ShellCore

struct MonthRef: Equatable {
    let year: Int
    let month: Int

    static func containing(_ date: Date, calendar: Calendar = .current) -> MonthRef {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return MonthRef(year: parts.year ?? 1970, month: parts.month ?? 1)
    }

    func adding(months: Int, calendar: Calendar = .current) -> MonthRef {
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        return .containing(calendar.date(byAdding: .month, value: months, to: first) ?? first, calendar: calendar)
    }
}

@MainActor
final class CalendarStore: ObservableObject {
    enum Access { case unknown, granted, denied }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var shown = MonthRef.containing(Date())
    @Published private(set) var now = Date()

    private lazy var store = EKEventStore()
    private var observers: [NSObjectProtocol] = []

    func start() {
        now = Date()
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            },
            center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.now = Date()
                    self?.reload()
                }
            },
        ]
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            access = .granted
            reload()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.access = granted ? .granted : .denied
                    self?.reload()
                }
            }
        default:
            access = .denied
        }
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        events = []
        shown = .containing(Date())
    }

    func showPrevious() { show(shown.adding(months: -1)) }
    func showNext() { show(shown.adding(months: 1)) }
    func showToday() { show(.containing(Date())) }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ month: MonthRef) {
        shown = month
        reload()
    }

    private func reload() {
        guard access == .granted, !observers.isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let monthStart = calendar.date(from: DateComponents(year: shown.year, month: shown.month, day: 1)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let agendaEnd = calendar.date(byAdding: .day, value: 2, to: today)
        else { return }
        let predicate = store.predicateForEvents(withStart: min(monthStart, today), end: max(monthEnd, agendaEnd), calendars: nil)
        events = store.events(matching: predicate).map { event in
            AgendaEvent(
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                isDeclined: event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined,
                colorHex: Self.hex(event.calendar?.color)
            )
        }
    }

    private static func hex(_ color: NSColor?) -> String {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return "" }
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02x%02x%02x", channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent))
    }
}
