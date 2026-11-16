import Foundation

public func applicationRoots(home: URL) -> [URL] {
    ["/Applications", "/System/Applications", home.appendingPathComponent("Applications").path,
     "/System/Library/CoreServices/Finder.app"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
}

public func scanApplications(roots: [URL]) -> [AppEntry] {
    var seen = Set<String>()
    var found: [AppEntry] = []
    func add(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        if seen.insert(name).inserted { found.append(AppEntry(name: name, url: url)) }
    }
    for root in roots {
        if root.pathExtension == "app" {
            if FileManager.default.fileExists(atPath: root.path) { add(root) }
            continue
        }
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { continue }
        for case let url as URL in walker where url.pathExtension == "app" {
            walker.skipDescendants()
            add(url)
        }
    }
    return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
