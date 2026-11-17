import AppKit
import ShellCore

@MainActor
final class MailSensor: ObservableObject {
    static let shared = MailSensor()

    @Published private(set) var unread: [MailSummary]?

    private var isFetching = false
    private static let queue = DispatchQueue(label: "local.celestia.shell.mail", qos: .utility)
    private static let bundleID = "com.apple.mail"
    private static let newestScanned = 20
    private static let script = """
    tell application "Mail"
        set out to ""
        try
            set newest to messages 1 thru \(newestScanned) of inbox
        on error
            set newest to messages of inbox
        end try
        repeat with m in newest
            if read status of m is false then
                set out to out & (sender of m) & (character id 31) & (subject of m) & (character id 31) & (message id of m) & (character id 30)
            end if
        end repeat
        return out
    end tell
    """

    func refresh() {
        guard !isFetching else { return }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty else {
            unread = []
            return
        }
        isFetching = true
        let script = Self.script
        Self.queue.async { [weak self] in
            var error: NSDictionary?
            let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
            let summaries = output.map { parseMailSummaries($0) }
            Task { @MainActor in
                guard let self else { return }
                self.isFetching = false
                if let summaries, summaries != self.unread { self.unread = summaries }
                if error != nil { shellLog("mail: \(error?[NSAppleScript.errorMessage] ?? "unknown error")") }
            }
        }
    }
}
