import Foundation
import ShellCore
import SQLite3

@MainActor
final class NotificationFeed {
    private let onNotice: @MainActor (IslandNotice) -> Void
    private var watcher: FileWatcher?
    private var isReading = false
    private var isStale = false
    private let reader = Reader()
    private static let queue = DispatchQueue(label: "local.celestia.shell.feed", qos: .utility)

    init(onNotice: @escaping @MainActor (IslandNotice) -> Void) {
        self.onNotice = onNotice
        watcher = FileWatcher(ShellPaths.notificationsWAL) { [weak self] in self?.read() }
        read()
    }

    private func read() {
        guard !isReading else { isStale = true; return }
        isReading = true
        let reader = reader
        Self.queue.async { [weak self] in
            let notices = reader.fresh(now: Date())
            Task { @MainActor in
                guard let self else { return }
                self.isReading = false
                notices.forEach(self.onNotice)
                if self.isStale { self.isStale = false; self.read() }
            }
        }
    }

    private final class Reader: @unchecked Sendable {
        private var cursor = FeedCursor()

        func fresh(now: Date) -> [IslandNotice] {
            guard let newest = NotificationDatabase.rows("select max(rec_id) from record", map: { sqlite3_column_int64($0, 0) })?.first
            else { return [] }
            guard let last = cursor.last, newest >= last else {
                _ = cursor.accept([(id: newest, delivered: .distantPast)], now: now)
                return []
            }
            let query = """
            select r.rec_id, a.identifier, r.data, r.delivered_date from record r
            join app a on a.app_id = r.app_id where r.rec_id > ? order by r.rec_id
            """
            let rows = NotificationDatabase.rows(query, [.integer(last)]) { statement -> (Int64, String, Data, Date)? in
                guard let app = NotificationDatabase.text(statement, 1), let data = NotificationDatabase.blob(statement, 2) else { return nil }
                return (sqlite3_column_int64(statement, 0), app, data, Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 3)))
            } ?? []
            let accepted = Set(cursor.accept(rows.map { (id: $0.0, delivered: $0.3) }, now: now))
            return rows
                .filter { accepted.contains($0.0) && !isIgnoredNotificationApp($0.1) }
                .compactMap { parseNotificationRecord($0.2, id: $0.0, app: $0.1) }
        }
    }
}
