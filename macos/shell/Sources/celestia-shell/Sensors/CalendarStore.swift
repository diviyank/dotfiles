import AppKit
@preconcurrency import EventKit
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
    @Published private(set) var selectedDay: Date?

    private lazy var store = EKEventStore()
    private var observers: [NSObjectProtocol] = []
    private var generation = 0
    private static let queue = DispatchQueue(label: "local.celestia.shell.calendar", qos: .userInitiated)

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
        generation += 1
        events = []
        selectedDay = nil
        shown = .containing(Date())
    }

    func showPrevious() { show(shown.adding(months: -1)) }
    func showNext() { show(shown.adding(months: 1)) }
    func showToday() { show(.containing(Date())) }

    func select(day: Int) {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: shown.year, month: shown.month, day: day)) else { return }
        selectedDay = calendar.isDate(date, inSameDayAs: now) || selectedDay.map({ calendar.isDate($0, inSameDayAs: date) }) == true ? nil : date
    }

    func open(_ event: AgendaEvent) {
        if let url = event.meetingURL ?? event.detailURL { NSWorkspace.shared.open(url) }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ month: MonthRef) {
        shown = month
        selectedDay = nil
        reload()
    }

    private func reload() {
        guard access == .granted, !observers.isEmpty else { return }
        generation += 1
        let request = generation
        let intervals = eventFetchIntervals(year: shown.year, month: shown.month, now: now, calendar: .current)
        let store = store
        Self.queue.async { [weak self] in
            let fetched = Self.fetch(intervals, from: store)
            Task { @MainActor in
                guard let self, self.generation == request, !self.observers.isEmpty else { return }
                self.events = fetched
            }
        }
    }

    nonisolated private static func fetch(_ intervals: [DateInterval], from store: EKEventStore) -> [AgendaEvent] {
        var seen = Set<String>()
        return intervals
            .flatMap { store.events(matching: store.predicateForEvents(withStart: $0.start, end: $0.end, calendars: nil)) }
            .filter { seen.insert("\($0.calendarItemIdentifier)|\($0.startDate.timeIntervalSince1970)").inserted }
            .map { event in
                AgendaEvent(
                    title: event.title ?? "",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    isDeclined: event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined,
                    colorHex: hex(event.calendar?.color),
                    meetingURL: meetingLink(url: event.url, location: event.location, notes: event.notes),
                    detailURL: event.calendarItemExternalIdentifier
                        .flatMap { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) }
                        .flatMap { URL(string: "ical://ekevent/\($0)?method=show&options=more") }
                )
            }
    }

    nonisolated private static func hex(_ color: NSColor?) -> String {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return "" }
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02x%02x%02x", channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent))
    }
}
