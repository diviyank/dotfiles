import AppKit

@MainActor
enum AppIcons {
    private static let capacity = 64
    private static var cache: [String: NSImage] = [:]
    private static var order: [String] = []

    static func icon(pid: Int32) -> NSImage? {
        guard let bundle = NSRunningApplication(processIdentifier: pid)?.bundleURL else { return nil }
        let key = bundle.path
        if let cached = cache[key] { return cached }
        let image = rasterized(NSWorkspace.shared.icon(forFile: key), side: Theme.Bar.spaceIcon)
        cache[key] = image
        order.append(key)
        if order.count > capacity { cache[order.removeFirst()] = nil }
        return image
    }

    private static func rasterized(_ source: NSImage, side: CGFloat) -> NSImage {
        let size = NSSize(width: side, height: side)
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(side * scale), pixelsHigh: Int(side * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return source }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        source.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
