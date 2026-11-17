import Foundation
import ShellCore

@MainActor
final class BadgeSensor: ObservableObject {
    static let shared = BadgeSensor()

    @Published private(set) var mail: String?
    @Published private(set) var discord: String?

    private var timer: Timer?

    private init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { BadgeSensor.shared.poll() }
        }
        timer?.tolerance = 5
    }

    private func poll() {
        Task.detached(priority: .utility) {
            let mail = Self.label("Mail")
            let discord = Self.label("Discord")
            await MainActor.run {
                if self.mail != mail { self.mail = mail }
                if self.discord != discord { self.discord = discord }
            }
        }
    }

    nonisolated private static func label(_ app: String) -> String? {
        runProcess("/usr/bin/lsappinfo", ["info", "-only", "StatusLabel", app])
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap(parseStatusLabel)
    }
}
