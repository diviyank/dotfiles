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

public func scanWallpapers(in dirs: [URL]) -> [URL] {
    var seen = Set<String>()
    let unique = dirs.flatMap { scanWallpapers(in: $0) }.filter { seen.insert($0.resolvingSymlinksInPath().path).inserted }
    return unique.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private func subdirectories(of dir: URL) -> [URL] {
    let entries = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
    return entries
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

public func appleWallpaperFolders(desktopPictures: URL, assets: URL) -> [URL] {
    let packages = subdirectories(of: desktopPictures.appendingPathComponent(".wallpapers", isDirectory: true))
    let downloads = subdirectories(of: assets)
        .filter { $0.pathExtension == "asset" }
        .map { $0.appendingPathComponent("AssetData", isDirectory: true) }
    return [desktopPictures] + packages + downloads
}

private func desktopChoices(in node: Any) -> [(set: Date, choice: [String: Any])] {
    if let list = node as? [Any] { return list.flatMap(desktopChoices) }
    guard let dict = node as? [String: Any] else { return [] }
    var found = dict.filter { $0.key != "Desktop" }.values.flatMap(desktopChoices)
    if let desktop = dict["Desktop"] as? [String: Any], let set = desktop["LastSet"] as? Date,
       let choice = ((desktop["Content"] as? [String: Any])?["Choices"] as? [[String: Any]])?.first {
        found.append((set, choice))
    }
    return found
}

public func latestDesktopImage(_ index: Data) -> URL? {
    guard let root = try? PropertyListSerialization.propertyList(from: index, format: nil),
          let latest = desktopChoices(in: root).max(by: { $0.set < $1.set })?.choice,
          latest["Provider"] as? String == "com.apple.wallpaper.choice.image",
          let file = (latest["Files"] as? [[String: Any]])?.first?["relative"] as? String
    else { return nil }
    return URL(string: file)
}

public func rankWallpapers(_ query: String, _ files: [URL]) -> [URL] {
    if query.isEmpty { return files }
    let scored = files.enumerated().compactMap { index, url in
        fuzzyScore(query, url.deletingPathExtension().lastPathComponent).map { (index, url, $0) }
    }
    return scored.sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }.map(\.1)
}

public func thumbnailURL(for wallpaper: URL, cacheDir: URL) -> URL {
    cacheDir.appendingPathComponent(wallpaper.lastPathComponent + ".jpg")
}

public func thumbnailIsStale(thumb: URL, source: URL) -> Bool {
    func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
    guard let thumbDate = modified(thumb) else { return true }
    guard let sourceDate = modified(source) else { return false }
    return thumbDate < sourceDate
}
