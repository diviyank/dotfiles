import Foundation
import Testing
@testable import ShellCore

final class SettingsTests {
    private let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: dir) }

    private func file(_ json: String) throws -> URL {
        let url = dir.appendingPathComponent("shell.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func missingFileGivesDefaults() {
        #expect(loadSettings(dir.appendingPathComponent("none.json")) == .defaults)
        #expect(ShellSettings.defaults.border == 6)
        #expect(ShellSettings.defaults.weatherLocation == "Paris")
    }

    @Test func readsValues() throws {
        let settings = loadSettings(try file(#"{"border": 0, "weather": {"location": "Lyon"}}"#))
        #expect(settings.border == 0)
        #expect(settings.weatherLocation == "Lyon")
    }

    @Test(arguments: [#"{"border": -3}"#, #"{"border": "abc"}"#, #"{"border": null}"#])
    func badBorderFallsBack(_ json: String) throws {
        #expect(loadSettings(try file(json)).border == 6)
    }

    @Test func corruptJsonGivesDefaults() throws {
        #expect(loadSettings(try file("{")) == .defaults)
    }
}
