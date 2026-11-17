import Foundation
import LauncherCore
import ShellCore
import SwiftUI

@MainActor
final class BarModel: ObservableObject {
    @Published private(set) var displays: [BarDisplay] = []
    @Published private(set) var palette = LauncherController.loadCurrentPalette()
    @Published private(set) var settings = loadSettings(ShellPaths.settings)

    private var isRefreshing = false
    private var needsRefresh = false

    func display(uuid: String) -> BarDisplay? {
        displays.first { $0.uuid == uuid }
    }

    func reloadPalette() {
        palette = LauncherController.loadCurrentPalette()
    }

    func preview(_ palette: Palette) {
        self.palette = palette
    }

    func reloadSettings() -> Bool {
        let fresh = loadSettings(ShellPaths.settings)
        guard fresh != settings else { return false }
        settings = fresh
        return true
    }

    func refresh() {
        guard !isRefreshing else {
            needsRefresh = true
            return
        }
        isRefreshing = true
        Task.detached(priority: .userInitiated) {
            let query = { (kind: String) in runProcess(ShellPaths.yabai, ["-m", "query", "--\(kind)"]) }
            let decoded = query("displays").flatMap { displays in
                query("spaces").flatMap { spaces in
                    query("windows").flatMap { windows in
                        decodeBarDisplays(displays: displays, spaces: spaces, windows: windows)
                    }
                }
            }
            await MainActor.run {
                if let decoded, decoded != self.displays { self.displays = decoded }
                self.isRefreshing = false
                if self.needsRefresh {
                    self.needsRefresh = false
                    self.refresh()
                }
            }
        }
    }

    func color(_ role: String, opacity: Double = 1) -> Color {
        let rgb = palette[role]
        return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }
}
