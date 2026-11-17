#if canImport(AppKit)
import AppKit
import LauncherCore

enum RowIcon {
    case glyph(String)
    case swatch(RGB)
}

enum RowAction {
    case action(LauncherAction)
    case copy(String)
    case scheme(String)
    case variant(String)
    case none
}

struct LauncherRow {
    let title: String
    let subtitle: String
    let icon: RowIcon
    let action: RowAction
}

enum Results {
    case apps([AppEntry])
    case rows([LauncherRow])
    case wallpapers([URL])

    var count: Int {
        switch self {
        case .apps(let apps): return apps.count
        case .rows(let rows): return rows.count
        case .wallpapers(let wallpapers): return wallpapers.count
        }
    }
}


private final class FlippedCanvas: NSView {
    var drawer: ((NSRect) -> Void)?
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { drawer?(dirtyRect) }
}

@MainActor
final class ResultsView: NSView {
    var palette: Palette
    var results: Results = .apps([])
    var selected = 0
    var maxCards = Theme.Launcher.maxCards

    private let icons: IconCache
    private let thumbs: ThumbnailCache
    private let highlight = NSView()
    private let canvas = FlippedCanvas()

    private let nameFont = Theme.text(Theme.TextSize.bodyMedium)
    private let subtitleFont = Theme.text(Theme.TextSize.bodySmall)
    private let emptyFont = Theme.text(Theme.TextSize.bodyLarge)
    private let cardLabelFont = Theme.text(Theme.TextSize.labelMedium, weight: .medium)
    private let commandIconFont = Theme.icon(Theme.IconSize.large)

    init(palette: Palette, icons: IconCache, thumbs: ThumbnailCache) {
        self.palette = palette
        self.icons = icons
        self.thumbs = thumbs
        super.init(frame: .zero)
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = Theme.Rounding.large
        addSubview(highlight)
        addSubview(canvas)
        canvas.drawer = { [unowned self] _ in self.drawContent() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }

    private var cardLabelHeight: CGFloat { Theme.lineHeight(cardLabelFont) }

    private var visibleCardCount: Int { min(results.count, maxCards) }

    private var firstVisibleCard: Int {
        let visible = visibleCardCount
        return max(0, min(selected - visible / 2, results.count - visible))
    }

    var preferredSize: NSSize {
        let listWidth = Theme.Launcher.contentWidth
        switch results {
        case .wallpapers(let wallpapers) where !wallpapers.isEmpty:
            let cards = CGFloat(visibleCardCount)
            let width = cards * Theme.Launcher.cardWidth + (cards - 1) * Theme.Spacing.small
            let height = Theme.Launcher.cardHeight + Theme.Spacing.extraSmall + cardLabelHeight
            return NSSize(width: max(listWidth, width), height: height)
        default:
            return NSSize(width: listWidth, height: CGFloat(max(1, results.count)) * Theme.Launcher.itemHeight)
        }
    }

    func reload(animated: Bool) {
        canvas.frame = bounds
        highlight.layer?.backgroundColor = Theme.color(palette, "on_surface", alpha: Theme.Launcher.highlightAlpha).cgColor
        thumbsRequest()
        moveHighlight(animated: animated)
        canvas.needsDisplay = true
    }

    private func moveHighlight(animated: Bool) {
        let showsRows: Bool
        switch results {
        case .apps, .rows: showsRows = results.count > 0
        case .wallpapers: showsRows = false
        }
        highlight.isHidden = !showsRows
        let target = rowRect(selected)
        guard animated, showsRows else {
            highlight.frame = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.highlight.animator().frame = target
        }
    }

    private func thumbsRequest() {
        guard case .wallpapers(let wallpapers) = results else { return }
        let first = firstVisibleCard
        let visible = Array(wallpapers[first..<(first + visibleCardCount)])
        thumbs.request(visible) { [weak self] in self?.canvas.needsDisplay = true }
    }

    private func rowRect(_ index: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(index) * Theme.Launcher.itemHeight,
               width: bounds.width, height: Theme.Launcher.itemHeight)
    }

    private func drawContent() {
        guard results.count > 0 else {
            drawEmpty()
            return
        }
        switch results {
        case .apps(let apps):
            for (index, app) in apps.enumerated() {
                let subtitle = (app.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
                drawRow(index, title: app.name, subtitle: subtitle) { rect in
                    icons.icon(for: app)?.draw(in: rect, from: .zero, operation: .sourceOver,
                                                fraction: 1, respectFlipped: true, hints: nil)
                }
            }
        case .rows(let rows):
            for (index, row) in rows.enumerated() {
                drawRow(index, title: row.title, subtitle: row.subtitle) { rect in drawIcon(row.icon, in: rect) }
            }
        case .wallpapers(let wallpapers):
            let first = firstVisibleCard
            for (offset, wallpaper) in wallpapers[first..<(first + visibleCardCount)].enumerated() {
                drawCard(wallpaper, slot: offset, isSelected: first + offset == selected)
            }
        }
    }

    private func attributes(_ font: NSFont, _ role: String, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        return [.font: font, .foregroundColor: Theme.color(palette, role), .paragraphStyle: paragraph]
    }

    private func drawCentered(_ text: String, font: NSFont, role: String, in rect: NSRect) {
        let height = Theme.lineHeight(font)
        let line = NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        (text as NSString).draw(in: line, withAttributes: attributes(font, role, alignment: .center))
    }

    private func drawIcon(_ icon: RowIcon, in rect: NSRect) {
        switch icon {
        case .glyph(let glyph):
            drawCentered(glyph, font: commandIconFont, role: "on_surface_variant", in: rect)
        case .swatch(let rgb):
            let side = rect.width * Theme.Launcher.swatchScale
            let circle = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            NSColor(srgbRed: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: 1).setFill()
            NSBezierPath(ovalIn: circle).fill()
        }
    }

    private func drawEmpty() {
        drawCentered("No results", font: emptyFont, role: "on_surface_variant", in: rowRect(0))
    }

    private func drawRow(_ index: Int, title: String, subtitle: String, icon: (NSRect) -> Void) {
        let row = rowRect(index)
        let side = Theme.Launcher.appIcon
        let inset = Theme.Spacing.medium
        icon(NSRect(x: row.minX + inset, y: row.midY - side / 2, width: side, height: side))

        let textX = row.minX + inset + side + inset
        let textWidth = row.maxX - inset - textX
        let titleHeight = Theme.lineHeight(nameFont)
        let subtitleHeight = subtitle.isEmpty ? 0 : Theme.lineHeight(subtitleFont)
        let top = row.midY - (titleHeight + subtitleHeight) / 2
        (title as NSString).draw(in: NSRect(x: textX, y: top, width: textWidth, height: titleHeight),
                                 withAttributes: attributes(nameFont, "on_surface"))
        guard !subtitle.isEmpty else { return }
        (subtitle as NSString).draw(in: NSRect(x: textX, y: top + titleHeight, width: textWidth, height: subtitleHeight),
                                    withAttributes: attributes(subtitleFont, "outline"))
    }

    private func drawCard(_ wallpaper: URL, slot: Int, isSelected: Bool) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setAlpha(isSelected ? 1 : Theme.Launcher.dimmedCardAlpha)

        let totalWidth = CGFloat(visibleCardCount) * Theme.Launcher.cardWidth
            + CGFloat(visibleCardCount - 1) * Theme.Spacing.small
        let originX = (bounds.width - totalWidth) / 2 + CGFloat(slot) * (Theme.Launcher.cardWidth + Theme.Spacing.small)
        let frame = NSRect(x: originX, y: 0, width: Theme.Launcher.cardWidth, height: Theme.Launcher.cardHeight)
        let shape = NSBezierPath(roundedRect: frame, xRadius: Theme.Rounding.large, yRadius: Theme.Rounding.large)

        if let image = thumbs.thumbnail(for: wallpaper) {
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            image.draw(in: aspectFillRect(image.size, in: frame), from: .zero, operation: .sourceOver,
                       fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            Theme.color(palette, "surface_container").setFill()
            shape.fill()
            drawCentered(Theme.Glyph.image, font: commandIconFont, role: "outline", in: frame)
        }

        let label = NSRect(x: frame.minX, y: frame.maxY + Theme.Spacing.extraSmall,
                           width: frame.width, height: cardLabelHeight)
        (wallpaper.lastPathComponent as NSString).draw(
            in: label, withAttributes: attributes(cardLabelFont, "on_surface", alignment: .center)
        )
    }

    private func aspectFillRect(_ size: NSSize, in frame: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return frame }
        let scale = max(frame.width / size.width, frame.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return NSRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
    }
}
#endif
