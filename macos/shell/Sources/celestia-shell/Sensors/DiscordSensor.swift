import Foundation
import ShellCore
import SQLite3

@MainActor
final class DiscordSensor: ObservableObject {
    static let shared = DiscordSensor()

    @Published private(set) var notes: [DiscordNote] = []

    private var watcher: FileWatcher?
    private var isReading = false
    private var isStale = false
    private static let queue = DispatchQueue(label: "local.celestia.shell.discord", qos: .utility)
    nonisolated private static let shown = 5

    private init() {
        watcher = FileWatcher(ShellPaths.notificationsWAL) { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard !isReading else { isStale = true; return }
        isReading = true
        Self.queue.async { [weak self] in
            let notes = Self.read()
            Task { @MainActor in
                guard let self else { return }
                self.isReading = false
                if let notes, notes != self.notes { self.notes = notes }
                if self.isStale { self.isStale = false; self.refresh() }
            }
        }
    }

    nonisolated private static func read() -> [DiscordNote]? {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        guard sqlite3_open_v2(ShellPaths.notifications.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            shellLog("discord: cannot open notifications (\(String(cString: sqlite3_errmsg(database))))")
            return nil
        }
        let query = """
        select r.data from record r join app a on a.app_id = r.app_id
        where lower(a.identifier) = ? order by r.delivered_date desc limit \(shown)
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            shellLog("discord: \(String(cString: sqlite3_errmsg(database)))")
            return nil
        }
        sqlite3_bind_text(statement, 1, discordBundleID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        var notes: [DiscordNote] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else { continue }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
            if let note = parseDiscordRecord(data) { notes.append(note) }
        }
        return notes
    }
}
