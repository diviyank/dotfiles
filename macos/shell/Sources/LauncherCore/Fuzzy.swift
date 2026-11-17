import Foundation

public struct AppEntry: Equatable, Sendable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

private func fold(_ text: String) -> [Character] {
    Array(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))
}

public func fuzzyScore(_ query: String, _ candidate: String) -> Int? {
    let q = fold(query)
    let c = fold(candidate)
    if q.isEmpty { return 0 }
    if q.count > c.count { return nil }

    func isWordStart(_ j: Int) -> Bool {
        j == 0 || !(c[j - 1].isLetter || c[j - 1].isNumber)
    }
    func charScore(_ j: Int) -> Int {
        1 + (j == 0 ? 15 : (isWordStart(j) ? 10 : 0))
    }

    var previous = [Int?](repeating: nil, count: c.count)
    for j in 0..<c.count where c[j] == q[0] {
        previous[j] = charScore(j)
    }
    for i in 1..<max(q.count, 1) {
        var current = [Int?](repeating: nil, count: c.count)
        for j in 0..<c.count where c[j] == q[i] {
            var best: Int?
            for k in 0..<j {
                guard let base = previous[k] else { continue }
                let total = base + (k == j - 1 ? 5 : 0)
                if best == nil || total > best! { best = total }
            }
            if let best { current[j] = best + charScore(j) }
        }
        previous = current
    }
    guard let best = previous.compactMap({ $0 }).max() else { return nil }
    return best + (c.starts(with: q) ? 20 : 0)
}

public func rank(_ query: String, _ apps: [AppEntry], limit: Int = 7) -> [AppEntry] {
    let byName: (AppEntry, AppEntry) -> Bool = {
        $0.name.localizedStandardCompare($1.name) == .orderedAscending
    }
    if query.isEmpty { return Array(apps.sorted(by: byName).prefix(limit)) }
    let scored = apps.compactMap { app in fuzzyScore(query, app.name).map { (app, $0) } }
    let sorted = scored.sorted { l, r in
        if l.1 != r.1 { return l.1 > r.1 }
        if l.0.name.count != r.0.name.count { return l.0.name.count < r.0.name.count }
        return byName(l.0, r.0)
    }
    return sorted.prefix(limit).map(\.0)
}
