import Foundation
import SQLite3

enum NotificationDatabase {
    enum Value { case text(String), integer(Int64) }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func rows<Row>(_ query: String, _ values: [Value] = [], map: (OpaquePointer) -> Row?) -> [Row]? {
        var database: OpaquePointer?
        defer { sqlite3_close(database) }
        guard sqlite3_open_v2(ShellPaths.notifications.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            shellLog("notifications: cannot open (\(String(cString: sqlite3_errmsg(database))))")
            return nil
        }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            shellLog("notifications: \(String(cString: sqlite3_errmsg(database)))")
            return nil
        }
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
            case .integer(let number): sqlite3_bind_int64(statement, position, number)
            }
        }
        var rows: [Row] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let row = map(statement) { rows.append(row) }
        }
        return rows
    }

    static func blob(_ statement: OpaquePointer, _ column: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, column) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }

    static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }
}
