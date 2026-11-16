import XCTest
@testable import LauncherCore

final class LauncherCoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
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

    func testScanFindsNestedAppsNotInsideBundles() throws {
        try mkdir("A/Safari.app/Contents/Foo.app")
        try mkdir("A/Utilities/Terminal.app")
        try mkdir("B/Safari.app")
        let a = tmp.appendingPathComponent("A"), b = tmp.appendingPathComponent("B")
        let missing = tmp.appendingPathComponent("nope")
        let result = scanApplications(roots: [a, missing, b])
        XCTAssertEqual(result.map(\.name), ["Safari", "Terminal"])
        XCTAssertEqual(result[0].url.path, a.appendingPathComponent("Safari.app").path)
    }

    func testFuzzyBasics() {
        XCTAssertEqual(fuzzyScore("", "Safari"), 0)
        XCTAssertNil(fuzzyScore("xyz", "Safari"))
        XCTAssertNotNil(fuzzyScore("SAF", "safari"))
        XCTAssertNotNil(fuzzyScore("e", "É"))
    }

    func testRankPrefersPrefixAndWordStart() {
        XCTAssertEqual(rank("sl", apps(["Calendar", "Mail", "Slack"])).first?.name, "Slack")
        XCTAssertEqual(rank("vsc", apps(["Avast Security Center", "Visual Studio Code"])).first?.name, "Visual Studio Code")
        XCTAssertEqual(rank("mail", apps(["Mailspring", "Mail"])).first?.name, "Mail")
    }

    func testRankNoMatchIsEmpty() {
        XCTAssertTrue(rank("qqq", apps(["Safari", "Mail"])).isEmpty)
    }

    func testRankLimit() {
        let many = apps((0..<20).map { "App\($0)" })
        XCTAssertEqual(rank("app", many).count, 7)
        XCTAssertEqual(rank("", many).count, 7)
        XCTAssertEqual(rank("", apps(["b", "a"])).map(\.name), ["a", "b"])
    }

    func testParseMode() {
        XCTAssertEqual(parseMode(""), .apps(""))
        XCTAssertEqual(parseMode("saf"), .apps("saf"))
        XCTAssertEqual(parseMode(">"), .commands(""))
        XCTAssertEqual(parseMode(">wa"), .commands("wa"))
        XCTAssertEqual(parseMode(">wallpaper"), .wallpapers(""))
        XCTAssertEqual(parseMode(">wallpaper  lake "), .wallpapers("lake"))
    }

    func testScanWallpapersFiltersAndSorts() throws {
        for f in ["b.JPG", "a.png", "c.heic", "d.txt"] { try touch(f) }
        try mkdir("sub")
        try touch("sub/e.jpg")
        XCTAssertEqual(scanWallpapers(in: tmp).map(\.lastPathComponent), ["a.png", "b.JPG", "c.heic"])
    }

    func testScanWallpapersMissingDirIsEmpty() {
        XCTAssertEqual(scanWallpapers(in: tmp.appendingPathComponent("nope")), [])
    }

    func testRankWallpapers() {
        let files = ["lake.jpg", "forest.png", "Mountain.jpg"].map { URL(fileURLWithPath: "/w/\($0)") }
        XCTAssertEqual(rankWallpapers("", files), files)
        XCTAssertEqual(rankWallpapers("lk", files).map(\.lastPathComponent), ["lake.jpg"])
    }

    func testPaletteParsesHex() throws {
        try touch("p.json", ##"{"primary":"#ff8000"}"##)
        let p = loadPalette(primary: tmp.appendingPathComponent("p.json"), fallback: tmp.appendingPathComponent("none.json"))
        XCTAssertEqual(p["primary"], RGB(r: 1, g: 128.0 / 255, b: 0))
        XCTAssertEqual(p["missing_role"], RGB(r: 1, g: 0, b: 1))
    }

    func testPaletteFallsBackWhenMissingOrCorrupt() throws {
        try touch("fb.json", ##"{"primary":"#000000","surface":"#ffffff"}"##)
        try touch("bad.json", "{")
        let fb = tmp.appendingPathComponent("fb.json")
        let none = tmp.appendingPathComponent("none.json")
        XCTAssertEqual(loadPalette(primary: none, fallback: fb)["surface"], RGB(r: 1, g: 1, b: 1))
        XCTAssertEqual(loadPalette(primary: tmp.appendingPathComponent("bad.json"), fallback: fb)["surface"], RGB(r: 1, g: 1, b: 1))
        let neutral = loadPalette(primary: none, fallback: none)
        XCTAssertNotEqual(neutral["primary"], RGB(r: 1, g: 0, b: 1))
    }

    func testThumbnailStaleness() throws {
        let cache = tmp.appendingPathComponent("cache")
        let src = tmp.appendingPathComponent("a.png")
        try touch("a.png")
        let thumb = thumbnailURL(for: src, cacheDir: cache)
        XCTAssertEqual(thumb.path, cache.appendingPathComponent("a.png.jpg").path)
        XCTAssertTrue(thumbnailIsStale(thumb: thumb, source: src))
        try mkdir("cache")
        try touch("cache/a.png.jpg")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -100)], ofItemAtPath: src.path)
        XCTAssertFalse(thumbnailIsStale(thumb: thumb, source: src))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -200)], ofItemAtPath: thumb.path)
        XCTAssertTrue(thumbnailIsStale(thumb: thumb, source: src))
    }
}
