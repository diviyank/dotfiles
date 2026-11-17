import Foundation
#if canImport(AppKit)
import AppKit

@MainActor
private func serve() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let controller = ShellController()
    withExtendedLifetime(controller) { app.run() }
}

private func post(_ name: Notification.Name) {
    DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
}

switch CommandLine.arguments.dropFirst().first {
case "serve":
    MainActor.assumeIsolated { serve() }
case "toggle":
    post(launcherToggleNotification)
case "refresh":
    post(shellRefreshNotification)
default:
    FileHandle.standardError.write(Data("usage: celestia-shell serve | toggle | refresh\n".utf8))
    exit(2)
}
#else
FileHandle.standardError.write(Data("celestia-shell: macOS only\n".utf8))
exit(1)
#endif
