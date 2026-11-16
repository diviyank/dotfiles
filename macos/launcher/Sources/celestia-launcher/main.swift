import Foundation
#if canImport(AppKit)
import AppKit

@MainActor
private func serve() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let controller = LauncherController()
    withExtendedLifetime(controller) { app.run() }
}

switch CommandLine.arguments.dropFirst().first {
case "serve":
    MainActor.assumeIsolated { serve() }
case "toggle":
    DistributedNotificationCenter.default().postNotificationName(
        launcherToggleNotification, object: nil, userInfo: nil, deliverImmediately: true
    )
default:
    FileHandle.standardError.write(Data("usage: celestia-launcher serve | toggle\n".utf8))
    exit(2)
}
#else
FileHandle.standardError.write(Data("celestia-launcher: macOS only\n".utf8))
exit(1)
#endif
