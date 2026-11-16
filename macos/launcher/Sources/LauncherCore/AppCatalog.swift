import Foundation

public func scanApplications(roots: [URL]) -> [AppEntry] {
    var seen = Set<String>()
    var found: [AppEntry] = []
    for root in roots {
        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { continue }
        for case let url as URL in walker where url.pathExtension == "app" {
            walker.skipDescendants()
            let name = url.deletingPathExtension().lastPathComponent
            if seen.insert(name).inserted { found.append(AppEntry(name: name, url: url)) }
        }
    }
    return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
