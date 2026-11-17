#if canImport(AppKit)
import AppKit
import LauncherCore
import ShellCore

let launcherToggleNotification = Notification.Name("local.celestia.shell.toggle")
let shellRefreshNotification = Notification.Name("local.celestia.shell.refresh")

private func logError(_ message: String) {
    FileHandle.standardError.write(Data("celestia-shell: \(message)\n".utf8))
}

final class LauncherPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onCancel?() }

    static func make() -> LauncherPanel {
        let panel = LauncherPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
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
    private var scheme = SchemeState()
    private var isPreviewing = false
    private var previewGeneration = 0
    private var pendingPreview: DispatchWorkItem?
    private var previewProcess: Process?
    private var previewed: SchemeState?

    var onPreview: ((Palette?) -> Void)?

    private static let actionGlyphs = [
        "calc": Glyph.calculate, "scheme": Glyph.palette, "variant": Glyph.tune, "wallpaper": Glyph.wallpaper,
        "random": Glyph.shuffle, "light": Glyph.lightMode, "dark": Glyph.darkMode, "lock": Glyph.lock,
        "sleep": Glyph.sleep, "logout": Glyph.logout, "restart": Glyph.restart, "shutdown": Glyph.power,
    ]

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

    static func loadCurrentPalette() -> Palette {
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
        scheme = loadSchemeState(ShellPaths.scheme)
        applyPalette()
        field.stringValue = ""
        wallpapersScanned = false
        refresh(resetSelection: true)

        let target = panel.frame
        panel.setFrame(target.offsetBy(dx: 0, dy: -Theme.Spacing.large), display: false)
        panel.alphaValue = 0
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

    func hide() { hide(committing: false) }

    private func hide(committing: Bool) {
        guard panel.isVisible, !isHiding else { return }
        isHiding = true
        defer { isHiding = false }
        panel.orderOut(nil)
        pendingPreview?.cancel()
        previewProcess?.terminate()
        previewGeneration += 1
        if isPreviewing && !committing { revertPreview() }
        isPreviewing = false
        previewed = nil
    }

    private func rescanApps() {
        guard !isScanningApps else { return }
        isScanningApps = true
        let roots = applicationRoots(home: home)
        DispatchQueue.global(qos: .utility).async {
            let scanned = scanApplications(roots: roots)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isScanningApps = false
                guard scanned != self.apps else { return }
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
        var preferred = 0
        switch parseMode(field.stringValue) {
        case .apps(let query):
            results = .apps(rank(query, apps, limit: Theme.Launcher.maxRows))
        case .actions(let query):
            results = .rows(filterActions(query).map(actionRow))
        case .calculator(let query):
            results = .rows([calculatorRow(query)])
        case .schemes(let query):
            let presets = matching(query, schemePresets) { $0.title }
            preferred = presets.firstIndex { $0.name == scheme.name } ?? 0
            results = .rows(presets.map(schemeRow))
        case .variants(let query):
            let variants = matching(query, schemeVariants) { $0.title }
            preferred = variants.firstIndex { $0.type == scheme.variant } ?? 0
            results = .rows(variants.map(variantRow))
        case .wallpapers(let query):
            scanWallpapersIfNeeded()
            results = .wallpapers(rankWallpapers(query, wallpapers))
        }
        selected = resetSelection ? preferred : max(0, min(selected, results.count - 1))
        resultsView.results = results
        resultsView.selected = selected
        layoutPanel()
        resultsView.reload(animated: false)
        schedulePreview()
    }

    private func scanWallpapersIfNeeded() {
        guard !wallpapersScanned else { return }
        wallpapers = scanWallpapers(in: ShellPaths.wallpapers)
        wallpapersScanned = true
    }

    private func matching<T>(_ query: String, _ items: [T], key: (T) -> String) -> [T] {
        query.isEmpty ? items : items.filter { fuzzyScore(query, key($0)) != nil }
    }

    private func actionRow(_ action: LauncherAction) -> LauncherRow {
        LauncherRow(title: action.title, subtitle: action.subtitle,
                    icon: .glyph(Self.actionGlyphs[action.name] ?? Theme.Glyph.search), action: .action(action))
    }

    private func calculatorRow(_ query: String) -> LauncherRow {
        let icon = RowIcon.glyph(Glyph.calculate)
        guard !query.isEmpty else {
            return LauncherRow(title: "Type an expression", subtitle: "For example 2^10 / 3", icon: icon, action: .none)
        }
        guard let value = evaluate(query) else {
            return LauncherRow(title: "Invalid expression", subtitle: query, icon: icon, action: .none)
        }
        let result = formatResult(value)
        return LauncherRow(title: result, subtitle: "\(query)  ·  Enter to copy", icon: icon, action: .copy(result))
    }

    private func schemeRow(_ preset: SchemePreset) -> LauncherRow {
        let subtitle = preset.name == scheme.name ? "Current" : preset.seed == nil ? "From the wallpaper" : ""
        let icon = preset.seed.flatMap(rgb(hex:)).map(RowIcon.swatch) ?? .glyph(Glyph.wallpaper)
        return LauncherRow(title: preset.title, subtitle: subtitle, icon: icon, action: .scheme(preset.name))
    }

    private func variantRow(_ variant: SchemeVariant) -> LauncherRow {
        LauncherRow(title: variant.title, subtitle: variant.type == scheme.variant ? "Current" : "",
                    icon: .glyph(Glyph.tune), action: .variant(variant.type))
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
        schedulePreview()
    }

    private enum PreviewTarget {
        case current, waitForThumbnail
        case colours(SchemeState, URL)
    }

    private func previewTarget() -> PreviewTarget {
        switch resultsView.results {
        case .rows(let rows):
            guard rows.indices.contains(selected) else { return .current }
            var state = scheme
            switch rows[selected].action {
            case .scheme(let name): state.name = name
            case .variant(let type): state.variant = type
            default: return .current
            }
            return state == scheme ? .current : .colours(state, ShellPaths.wallpaperSource)
        case .wallpapers(let wallpapers):
            guard scheme.seed == nil, wallpapers.indices.contains(selected) else { return .current }
            let thumb = thumbnailURL(for: wallpapers[selected], cacheDir: ShellPaths.thumbnails)
            return FileManager.default.fileExists(atPath: thumb.path) ? .colours(scheme, thumb) : .waitForThumbnail
        case .apps:
            return .current
        }
    }

    private func schedulePreview() {
        pendingPreview?.cancel()
        previewGeneration += 1
        let generation = previewGeneration
        switch previewTarget() {
        case .waitForThumbnail:
            return
        case .current:
            previewProcess?.terminate()
            if isPreviewing { revertPreview() }
        case .colours(let state, let source):
            let item = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.runPreview(state, source: source, generation: generation) }
            }
            pendingPreview = item
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Launcher.previewDelay, execute: item)
        }
    }

    private func runPreview(_ state: SchemeState, source: URL, generation: Int) {
        previewProcess?.terminate()
        guard let matugen = ShellPaths.matugen else { return }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: matugen)
        process.arguments = matugenPreviewArguments(state, source: source)
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let palette = finished.terminationStatus == 0 ? parseMatugenPalette(data, mode: state.mode) : nil
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.applyPreview(palette, of: state, generation: generation) }
            }
        }
        do {
            try process.run()
            previewProcess = process
        } catch {
            logError("cannot run matugen: \(error.localizedDescription)")
        }
    }

    private func applyPreview(_ preview: Palette?, of state: SchemeState, generation: Int) {
        guard generation == previewGeneration, panel.isVisible else { return }
        guard let preview else {
            if isPreviewing { revertPreview() }
            return
        }
        isPreviewing = true
        previewed = state
        show(preview)
        onPreview?(preview)
    }

    private func revertPreview() {
        isPreviewing = false
        previewed = nil
        show(Self.loadCurrentPalette())
        onPreview?(nil)
    }

    private func show(_ palette: Palette) {
        self.palette = palette
        applyPalette()
        resultsView.reload(animated: false)
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
        case .rows(let rows):
            guard rows.indices.contains(selected) else { return }
            switch rows[selected].action {
            case .action(let action): perform(action)
            case .copy(let text):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                hide()
            case .scheme(let name): commit { $0.name = name }
            case .variant(let type): commit { $0.variant = type }
            case .none: break
            }
        case .wallpapers(let wallpapers):
            guard wallpapers.indices.contains(selected) else { return }
            runWallpaperScript([wallpapers[selected].path])
            hide(committing: isPreviewing)
        }
    }

    private func perform(_ action: LauncherAction) {
        if action.takesQuery {
            field.stringValue = ">\(action.name) "
            field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.utf16.count, length: 0)
            refresh(resetSelection: true)
            return
        }
        switch action.name {
        case "random": setRandomWallpaper()
        case "light": commit { $0.mode = "light" }
        case "dark": commit { $0.mode = "dark" }
        default:
            hide()
            switch action.name {
            case "lock": PowerActions.lock()
            case "sleep": PowerActions.sleep()
            case "logout": PowerActions.logOut()
            case "restart": PowerActions.restart()
            case "shutdown": PowerActions.shutDown()
            default: logError("unknown action \(action.name)")
            }
        }
    }

    private func commit(_ change: (inout SchemeState) -> Void) {
        var state = scheme
        change(&state)
        do {
            try saveSchemeState(state, to: ShellPaths.scheme)
        } catch {
            logError("cannot save the scheme: \(error.localizedDescription)")
            return hide()
        }
        scheme = state
        runWallpaperScript(["--recolour"])
        hide(committing: isPreviewing && previewed == state)
    }

    private func setRandomWallpaper() {
        scanWallpapersIfNeeded()
        let current = (try? String(contentsOf: ShellPaths.currentWallpaper, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pick = wallpapers.filter({ $0.path != current }).randomElement() ?? wallpapers.first else {
            return hide()
        }
        runWallpaperScript([pick.path])
        hide()
    }

    private func runWallpaperScript(_ arguments: [String]) {
        let process = Process()
        process.executableURL = ShellPaths.wallpaperScript
        process.arguments = arguments
        process.terminationHandler = { finished in
            guard finished.terminationStatus != 0 else { return }
            logError("celestia-wallpaper exited with status \(finished.terminationStatus)")
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.onPreview?(nil) }
            }
        }
        do {
            try process.run()
        } catch {
            logError("cannot run \(ShellPaths.wallpaperScript.path): \(error.localizedDescription)")
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
