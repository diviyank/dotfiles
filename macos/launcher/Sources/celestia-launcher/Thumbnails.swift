#if canImport(AppKit)
import AppKit
import ImageIO
import LauncherCore

private func rasterize(_ image: NSImage, points: NSSize) -> NSImage {
    var rect = NSRect(x: 0, y: 0, width: points.width * 2, height: points.height * 2)
    guard let bitmap = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return image }
    return NSImage(cgImage: bitmap, size: points)
}

@MainActor
final class IconCache {
    private var images: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "local.celestia.launcher.icons", qos: .utility)

    func icon(for app: AppEntry) -> NSImage? {
        images[app.url.path]
    }

    func warm(_ apps: [AppEntry], then done: @escaping () -> Void) {
        let missing = apps.map(\.url.path).filter { images[$0] == nil }
        guard !missing.isEmpty else { return }
        let side = Theme.Launcher.appIcon
        queue.async {
            let made = Dictionary(uniqueKeysWithValues: missing.map { path in
                (path, rasterize(NSWorkspace.shared.icon(forFile: path), points: NSSize(width: side, height: side)))
            })
            DispatchQueue.main.async { [weak self] in
                self?.images.merge(made) { kept, _ in kept }
                done()
            }
        }
    }
}

private let thumbnailPixels = (width: 560, height: 400)

private func aspectFill(_ source: CGSize, into target: CGSize) -> CGRect {
    let scale = max(target.width / source.width, target.height / source.height)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    return CGRect(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2,
                  width: size.width, height: size.height)
}

private func renderThumbnail(of source: URL, to destination: URL) -> CGImage? {
    let decodeOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: thumbnailPixels.width * 2,
    ]
    guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
          let decoded = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, decodeOptions as CFDictionary),
          let context = CGContext(
              data: nil, width: thumbnailPixels.width, height: thumbnailPixels.height,
              bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          )
    else { return nil }
    let target = CGSize(width: thumbnailPixels.width, height: thumbnailPixels.height)
    context.interpolationQuality = .high
    context.draw(decoded, in: aspectFill(CGSize(width: decoded.width, height: decoded.height), into: target))
    guard let thumbnail = context.makeImage() else { return nil }
    if let writer = CGImageDestinationCreateWithURL(destination as CFURL, "public.jpeg" as CFString, 1, nil) {
        CGImageDestinationAddImage(writer, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(writer)
    }
    return thumbnail
}

private func loadThumbnail(for wallpaper: URL, cacheDir: URL) -> NSImage? {
    let points = NSSize(width: Theme.Launcher.cardWidth, height: Theme.Launcher.cardHeight)
    let thumb = thumbnailURL(for: wallpaper, cacheDir: cacheDir)
    if !thumbnailIsStale(thumb: thumb, source: wallpaper), let cached = NSImage(contentsOf: thumb) {
        return rasterize(cached, points: points)
    }
    return renderThumbnail(of: wallpaper, to: thumb).map { NSImage(cgImage: $0, size: points) }
}

@MainActor
final class ThumbnailCache {
    private var images: [String: NSImage] = [:]
    private var pending = Set<String>()
    private let queue = DispatchQueue(label: "local.celestia.launcher.thumbs", qos: .utility)
    private let cacheDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cache/celestia/thumbs", isDirectory: true)

    func thumbnail(for wallpaper: URL) -> NSImage? {
        images[wallpaper.path]
    }

    func request(_ wallpapers: [URL], then done: @escaping () -> Void) {
        let missing = wallpapers.filter { images[$0.path] == nil && !pending.contains($0.path) }
        guard !missing.isEmpty else { return }
        pending.formUnion(missing.map(\.path))
        let cacheDir = self.cacheDir
        queue.async {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            for wallpaper in missing {
                let image = loadThumbnail(for: wallpaper, cacheDir: cacheDir)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.pending.remove(wallpaper.path)
                    if let image { self.images[wallpaper.path] = image }
                    done()
                }
            }
        }
    }
}
#endif
