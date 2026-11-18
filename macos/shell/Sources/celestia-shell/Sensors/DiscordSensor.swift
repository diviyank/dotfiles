import Foundation
import ShellCore

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
        let query = """
        select r.data from record r join app a on a.app_id = r.app_id
        where lower(a.identifier) = ? order by r.delivered_date desc limit \(shown)
        """
        return NotificationDatabase.rows(query, [.text(discordBundleID)]) { statement in
            NotificationDatabase.blob(statement, 0).flatMap(parseDiscordRecord)
        }
    }
}
