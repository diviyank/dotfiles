#if canImport(AppKit)
import AppKit
import LauncherCore

let launcherToggleNotification = Notification.Name("local.celestia.launcher.toggle")

private func logError(_ message: String) {
    FileHandle.standardError.write(Data("celestia-launcher: \(message)\n".utf8))
}

final class LauncherPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onCancel?() }

    static func make() -> LauncherPanel {
        let panel = LauncherPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        return panel
    }
}

@MainActor
final class LauncherController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let panel = LauncherPanel.make()
    private let root = NSView()
    private let searchPill = NSView()
    private let searchGlyph = NSTextField(labelWithString: Theme.Glyph.search)
    private let field = NSTextField()
    private let searchFont = Theme.text(Theme.TextSize.bodyMedium)
    private let icons: IconCache
    private let thumbs: ThumbnailCache
    private let resultsView: ResultsView

    private var palette: Palette
    private var apps: [AppEntry] = []
    private var wallpapers: [URL] = []
    private var wallpapersScanned = false
    private var isScanningApps = false
    private var isHiding = false
    private var selected = 0
    private var screenFrame = NSRect.zero

    override init() {
        let palette = Self.loadCurrentPalette()
        let icons = IconCache()
        let thumbs = ThumbnailCache()
        self.palette = palette
        self.icons = icons
        self.thumbs = thumbs
        resultsView = ResultsView(palette: palette, icons: icons, thumbs: thumbs)
        super.init()
        buildViews()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(toggle), name: launcherToggleNotification, object: nil
        )
        rescanApps()
    }

    private static func loadCurrentPalette() -> Palette {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return loadPalette(
            primary: home.appendingPathComponent(".local/state/celestia/colors.json"),
            fallback: home.appendingPathComponent(".config/celestia/default-colors.json")
        )
    }

    private func buildViews() {
        root.wantsLayer = true
        root.layer?.cornerRadius = Theme.Rounding.extraLarge
        root.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        searchPill.wantsLayer = true
        searchGlyph.font = Theme.icon(Theme.IconSize.search)
        searchGlyph.alignment = .center

        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.font = searchFont
        field.delegate = self

        searchPill.addSubview(searchGlyph)
        searchPill.addSubview(field)
        root.addSubview(resultsView)
        root.addSubview(searchPill)
        panel.contentView = root
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    private func applyPalette() {
        root.layer?.backgroundColor = Theme.color(palette, "surface").cgColor
        searchPill.layer?.backgroundColor = Theme.color(palette, "surface_container").cgColor
        searchGlyph.textColor = Theme.color(palette, "on_surface_variant")
        field.textColor = Theme.color(palette, "on_surface")
        field.placeholderAttributedString = NSAttributedString(
            string: Theme.Launcher.placeholder,
            attributes: [.font: searchFont, .foregroundColor: Theme.color(palette, "outline")]
        )
        resultsView.palette = palette
    }

    @objc private func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        screenFrame = screen.visibleFrame
        let pad = Theme.Launcher.padding
        let cardStep = Theme.Launcher.cardWidth + Theme.Spacing.small
        let fittingCards = Int((screenFrame.width - 2 * pad + Theme.Spacing.small) / cardStep)
        resultsView.maxCards = max(1, min(Theme.Launcher.maxCards, fittingCards))

        palette = Self.loadCurrentPalette()
        applyPalette()
        field.stringValue = ""
        wallpapersScanned = false
        refresh(resetSelection: true)

        let target = panel.frame
        panel.setFrame(target.offsetBy(dx: 0, dy: -Theme.Spacing.large), display: false)
        panel.alphaValue = 0
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        (field.currentEditor() as? NSTextView)?.insertionPointColor = Theme.color(palette, "on_surface")
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel.animator().setFrame(target, display: true)
            self.panel.animator().alphaValue = 1
        }
        rescanApps()
    }

    func hide() {
        guard panel.isVisible, !isHiding else { return }
        isHiding = true
        defer { isHiding = false }
        panel.orderOut(nil)
        if NSApp.isActive { NSApp.hide(nil) }
    }

    private func rescanApps() {
        guard !isScanningApps else { return }
        isScanningApps = true
        let roots = ["/Applications", "/System/Applications", home.appendingPathComponent("Applications").path]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        DispatchQueue.global(qos: .utility).async {
            let scanned = scanApplications(roots: roots)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isScanningApps = false
                self.apps = scanned
                self.icons.warm(scanned) { [weak self] in self?.redrawIfVisible() }
                self.redrawIfVisible()
            }
        }
    }

    private func redrawIfVisible() {
        guard panel.isVisible else { return }
        refresh(resetSelection: false)
    }

    private func refresh(resetSelection: Bool) {
        let results: Results
        switch parseMode(field.stringValue) {
        case .apps(let query):
            results = .apps(rank(query, apps, limit: Theme.Launcher.maxRows))
        case .commands(let query):
            results = .commands(launcherCommands.filter { fuzzyScore(query, $0) != nil })
        case .wallpapers(let query):
            if !wallpapersScanned {
                wallpapers = scanWallpapers(in: home.appendingPathComponent("Pictures/Wallpapers", isDirectory: true))
                wallpapersScanned = true
            }
            results = .wallpapers(rankWallpapers(query, wallpapers))
        }
        selected = resetSelection ? 0 : max(0, min(selected, results.count - 1))
        resultsView.results = results
        resultsView.selected = selected
        layoutPanel()
        resultsView.reload(animated: false)
    }

    private func layoutPanel() {
        let pad = Theme.Launcher.padding
        let list = resultsView.preferredSize
        let searchHeight = Theme.lineHeight(searchFont) + 2 * Theme.Launcher.searchVerticalPadding
        let width = min(list.width + 2 * pad, screenFrame.width)
        let height = pad + list.height + Theme.Spacing.medium + searchHeight + pad

        panel.setFrame(NSRect(x: screenFrame.midX - width / 2, y: screenFrame.minY, width: width, height: height),
                       display: true)
        root.frame = NSRect(x: 0, y: 0, width: width, height: height)

        searchPill.frame = NSRect(x: pad, y: pad, width: width - 2 * pad, height: searchHeight)
        searchPill.layer?.cornerRadius = searchHeight / 2
        let glyphSide = Theme.IconSize.search
        let glyphHeight = Theme.lineHeight(searchGlyph.font ?? searchFont)
        searchGlyph.frame = NSRect(x: Theme.Spacing.large, y: (searchHeight - glyphHeight) / 2,
                                   width: glyphSide, height: glyphHeight)
        let fieldX = Theme.Spacing.large + glyphSide + Theme.Spacing.medium
        let fieldHeight = Theme.lineHeight(searchFont)
        field.frame = NSRect(x: fieldX, y: (searchHeight - fieldHeight) / 2,
                             width: searchPill.frame.width - fieldX - Theme.Spacing.large, height: fieldHeight)

        resultsView.frame = NSRect(x: (width - list.width) / 2, y: pad + searchHeight + Theme.Spacing.medium,
                                   width: list.width, height: list.height)
    }

    private var isWallpaperMode: Bool {
        if case .wallpapers = resultsView.results { return true }
        return false
    }

    private func move(_ delta: Int) {
        let count = resultsView.results.count
        guard count > 0 else { return }
        selected = max(0, min(count - 1, selected + delta))
        resultsView.selected = selected
        resultsView.reload(animated: true)
    }

    private func activateSelection() {
        switch resultsView.results {
        case .apps(let apps):
            guard apps.indices.contains(selected) else { return }
            let app = apps[selected]
            NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                guard let error else { return }
                logError("cannot open \(app.url.path): \(error.localizedDescription)")
            }
            hide()
        case .commands(let commands):
            guard commands.indices.contains(selected) else { return }
            field.stringValue = ">\(commands[selected]) "
            field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0)
            refresh(resetSelection: true)
        case .wallpapers(let wallpapers):
            guard wallpapers.indices.contains(selected) else { return }
            let process = Process()
            process.executableURL = home.appendingPathComponent(".local/bin/celestia-wallpaper")
            process.arguments = [wallpapers[selected].path]
            do {
                try process.run()
            } catch {
                logError("cannot run \(process.executableURL?.path ?? "celestia-wallpaper"): \(error.localizedDescription)")
            }
            hide()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        refresh(resetSelection: true)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.insertBacktab(_:)):
            move(-1)
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)):
            move(1)
        case #selector(NSResponder.moveLeft(_:)) where isWallpaperMode:
            move(-1)
        case #selector(NSResponder.moveRight(_:)) where isWallpaperMode:
            move(1)
        case #selector(NSResponder.insertNewline(_:)):
            activateSelection()
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
        default:
            return false
        }
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
#endif
