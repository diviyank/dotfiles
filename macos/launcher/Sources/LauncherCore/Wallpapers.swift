import Foundation

private let wallpaperExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]

public func scanWallpapers(in dir: URL) -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? []
    return files
        .filter { wallpaperExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

public func rankWallpapers(_ query: String, _ files: [URL]) -> [URL] {
    if query.isEmpty { return files }
    let scored = files.enumerated().compactMap { index, url in
        fuzzyScore(query, url.lastPathComponent).map { (index, url, $0) }
    }
    return scored.sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }.map(\.1)
}

public func thumbnailURL(for wallpaper: URL, cacheDir: URL) -> URL {
    cacheDir.appendingPathComponent(wallpaper.lastPathComponent + ".jpg")
}

public func thumbnailIsStale(thumb: URL, source: URL) -> Bool {
    func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
    guard let thumbDate = modified(thumb) else { return true }
    guard let sourceDate = modified(source) else { return false }
    return thumbDate < sourceDate
}
