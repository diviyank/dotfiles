import Foundation
import Testing
@testable import LauncherCore

final class LauncherCoreTests {
    private let tmp: URL

    init() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func mkdir(_ path: String) throws {
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent(path), withIntermediateDirectories: true)
    }

    private func touch(_ path: String, _ content: String = "") throws {
        try content.write(to: tmp.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }

    private func apps(_ names: [String]) -> [AppEntry] {
        names.map { AppEntry(name: $0, url: URL(fileURLWithPath: "/Applications/\($0).app")) }
    }

    @Test func scanFindsNestedAppsNotInsideBundles() throws {
        try mkdir("A/Safari.app/Contents/Foo.app")
        try mkdir("A/Utilities/Terminal.app")
        try mkdir("B/Safari.app")
        let a = tmp.appendingPathComponent("A"), b = tmp.appendingPathComponent("B")
        let missing = tmp.appendingPathComponent("nope")
        let result = scanApplications(roots: [a, missing, b])
        #expect(result.map(\.name) == ["Safari", "Terminal"])
        #expect(result[0].url.resolvingSymlinksInPath() == a.appendingPathComponent("Safari.app").resolvingSymlinksInPath())
    }

    @Test func scanAcceptsBundleRoots() throws {
        try mkdir("CoreServices/Finder.app/Contents")
        try mkdir("A/Safari.app")
        let finder = tmp.appendingPathComponent("CoreServices/Finder.app")
        let result = scanApplications(roots: [tmp.appendingPathComponent("A"), finder,
                                              tmp.appendingPathComponent("Missing.app")])
        #expect(result.map(\.name) == ["Finder", "Safari"])
        #expect(result[0].url.path == finder.path)
    }

    @Test func applicationRootsIncludeFinder() {
        let roots = applicationRoots(home: URL(fileURLWithPath: "/Users/me")).map(\.path)
        #expect(roots.contains("/System/Library/CoreServices/Finder.app"))
        #expect(roots.contains("/Users/me/Applications"))
    }

    @Test func fuzzyBasics() {
        #expect(fuzzyScore("", "Safari") == 0)
        #expect(fuzzyScore("xyz", "Safari") == nil)
        #expect(fuzzyScore("SAF", "safari") != nil)
        #expect(fuzzyScore("e", "É") != nil)
    }

    @Test func rankPrefersPrefixAndWordStart() {
        #expect(rank("sl", apps(["Calendar", "Mail", "Slack"])).first?.name == "Slack")
        #expect(rank("vsc", apps(["Avast Security Center", "Visual Studio Code"])).first?.name == "Visual Studio Code")
        #expect(rank("mail", apps(["Mailspring", "Mail"])).first?.name == "Mail")
    }

    @Test func rankNoMatchIsEmpty() {
        #expect(rank("qqq", apps(["Safari", "Mail"])).isEmpty)
    }

    @Test func rankLimit() {
        let many = apps((0..<20).map { "App\($0)" })
        #expect(rank("app", many).count == 7)
        #expect(rank("", many).count == 7)
        #expect(rank("", apps(["b", "a"])).map(\.name) == ["a", "b"])
    }

    @Test func parsesModes() {
        #expect(parseMode("") == .apps(""))
        #expect(parseMode("saf") == .apps("saf"))
        #expect(parseMode(">") == .commands(""))
        #expect(parseMode(">wa") == .commands("wa"))
        #expect(parseMode(">wallpaper") == .wallpapers(""))
        #expect(parseMode(">wallpaper  lake ") == .wallpapers("lake"))
    }

    @Test func scanWallpapersFiltersAndSorts() throws {
        for f in ["b.JPG", "a.png", "c.heic", "d.txt"] { try touch(f) }
        try mkdir("sub")
        try touch("sub/e.jpg")
        #expect(scanWallpapers(in: tmp).map(\.lastPathComponent) == ["a.png", "b.JPG", "c.heic"])
    }

    @Test func scanWallpapersMissingDirIsEmpty() {
        #expect(scanWallpapers(in: tmp.appendingPathComponent("nope")) == [])
    }

    @Test func ranksWallpapers() {
        let files = ["lake.jpg", "forest.png", "Mountain.jpg"].map { URL(fileURLWithPath: "/w/\($0)") }
        #expect(rankWallpapers("", files) == files)
        #expect(rankWallpapers("lk", files).map(\.lastPathComponent) == ["lake.jpg"])
        #expect(rankWallpapers("j", files) == [])
    }

    @Test func paletteParsesHex() throws {
        try touch("p.json", ##"{"primary":"#ff8000"}"##)
        let p = loadPalette(primary: tmp.appendingPathComponent("p.json"), fallback: tmp.appendingPathComponent("none.json"))
        #expect(p["primary"] == RGB(r: 1, g: 128.0 / 255, b: 0))
        #expect(p["missing_role"] == RGB(r: 1, g: 0, b: 1))
    }

    @Test func paletteFallsBackWhenMissingOrCorrupt() throws {
        try touch("fb.json", ##"{"primary":"#000000","surface":"#ffffff"}"##)
        try touch("bad.json", "{")
        let fb = tmp.appendingPathComponent("fb.json")
        let none = tmp.appendingPathComponent("none.json")
        #expect(loadPalette(primary: none, fallback: fb)["surface"] == RGB(r: 1, g: 1, b: 1))
        #expect(loadPalette(primary: tmp.appendingPathComponent("bad.json"), fallback: fb)["surface"] == RGB(r: 1, g: 1, b: 1))
        let neutral = loadPalette(primary: none, fallback: none)
        #expect(neutral["primary"] != RGB(r: 1, g: 0, b: 1))
    }

    @Test func thumbnailStaleness() throws {
        let cache = tmp.appendingPathComponent("cache")
        let src = tmp.appendingPathComponent("a.png")
        try touch("a.png")
        let thumb = thumbnailURL(for: src, cacheDir: cache)
        #expect(thumb.path == cache.appendingPathComponent("a.png.jpg").path)
        #expect(thumbnailIsStale(thumb: thumb, source: src))
        try mkdir("cache")
        try touch("cache/a.png.jpg")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -100)], ofItemAtPath: src.path)
        #expect(!thumbnailIsStale(thumb: thumb, source: src))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -200)], ofItemAtPath: thumb.path)
        #expect(thumbnailIsStale(thumb: thumb, source: src))
    }
}
