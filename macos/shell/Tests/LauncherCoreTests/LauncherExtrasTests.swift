import Foundation
import Testing
@testable import LauncherCore

@Test func extraModesParse() {
    #expect(parseMode(">calc 2+2") == .calculator("2+2"))
    #expect(parseMode(">calc") == .calculator(""))
    #expect(parseMode(">scheme ros") == .schemes("ros"))
    #expect(parseMode(">variant") == .variants(""))
    #expect(parseMode(">calculator") == .actions("calculator"))
}

@Test func actionsAreFilteredFuzzily() {
    #expect(launcherActions.map(\.name) == [
        "calc", "scheme", "variant", "wallpaper", "random", "light", "dark",
        "lock", "sleep", "logout", "restart", "shutdown",
    ])
    #expect(filterActions("").count == launcherActions.count)
    #expect(filterActions("dar").first?.name == "dark")
    #expect(filterActions("zzz").isEmpty)
    #expect(launcherActions.filter(\.takesQuery).map(\.name) == ["calc", "scheme", "variant", "wallpaper"])
}

@Test func calculatorEvaluatesArithmetic() {
    #expect(evaluate("2+3*4") == 14)
    #expect(evaluate("(2+3)*4") == 20)
    #expect(evaluate("2^3^2") == 512)
    #expect(evaluate("-3^2") == -9)
    #expect(evaluate("10 % 4") == 2)
    #expect(evaluate("1.5e3 / 3") == 500)
    #expect(evaluate("2 × 3 ÷ 4") == 1.5)
    #expect(evaluate("sqrt(16) + abs(-2)") == 6)
    #expect(abs(evaluate("sin(pi/2)")! - 1) < 1e-12)
    #expect(abs(evaluate("ln(e)")! - 1) < 1e-12)
    #expect(evaluate("log(1000)") == 3)
    #expect(evaluate("2(3)") == 6)
}

@Test func calculatorRejectsBadInput() {
    #expect(evaluate("") == nil)
    #expect(evaluate("2+") == nil)
    #expect(evaluate("(2") == nil)
    #expect(evaluate("foo(2)") == nil)
    #expect(evaluate("1/0") == nil)
    #expect(evaluate("sqrt(-1)") == nil)
    #expect(evaluate(String(repeating: "(", count: 500) + "1" + String(repeating: ")", count: 500)) == nil)
}

@Test func calculatorFormatsResults() {
    #expect(formatResult(14) == "14")
    #expect(formatResult(1.5) == "1.5")
    #expect(formatResult(1.0 / 3) == "0.333333333333")
    #expect(formatResult(-0.0) == "0")
    #expect(formatResult(1e21) == "1e+21")
}

@Test func schemeStateDefaultsAndRoundTrips() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("scheme.json")
    #expect(loadSchemeState(file) == SchemeState())
    #expect(SchemeState() == SchemeState(name: "dynamic", variant: "scheme-tonal-spot", mode: "dark"))
    let state = SchemeState(name: "rosepine", variant: "scheme-expressive", mode: "light")
    try saveSchemeState(state, to: file)
    #expect(loadSchemeState(file) == state)
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: String]
    #expect(json?["seed"] == schemePresets.first { $0.name == "rosepine" }?.seed)
}

@Test func schemePresetsStartWithDynamic() {
    #expect(schemePresets.first?.name == "dynamic")
    #expect(schemePresets.first?.seed == nil)
    #expect(schemePresets.dropFirst().allSatisfy { $0.seed?.count == 7 })
    #expect(schemeVariants.map(\.type).contains("scheme-tonal-spot"))
    #expect(schemeVariants.count == 8)
}

@Test func matugenArgumentsFollowTheScheme() {
    let source = URL(fileURLWithPath: "/s/source.jpg")
    #expect(matugenPreviewArguments(SchemeState(), source: source) == [
        "image", "/s/source.jpg", "-t", "scheme-tonal-spot", "-m", "dark", "--dry-run", "-j", "hex", "-q",
    ])
    let preset = SchemeState(name: "nord", variant: "scheme-content", mode: "light")
    let seed = schemePresets.first { $0.name == "nord" }!.seed!
    #expect(matugenPreviewArguments(preset, source: source) == [
        "color", "hex", seed, "-t", "scheme-content", "-m", "light", "--dry-run", "-j", "hex", "-q",
    ])
}

@Test func matugenJSONBecomesAPalette() throws {
    let json = ##"{"colors":{"dark":{"primary":"#a4d397","surface":"#11140f"},"light":{"primary":"#3e6837"}}}"##
    let dark = try #require(parseMatugenPalette(Data(json.utf8), mode: "dark"))
    #expect(dark["primary"] == RGB(r: 0xa4 / 255.0, g: 0xd3 / 255.0, b: 0x97 / 255.0))
    #expect(parseMatugenPalette(Data(json.utf8), mode: "light")?["primary"] == RGB(r: 0x3e / 255.0, g: 0x68 / 255.0, b: 0x37 / 255.0))
    #expect(parseMatugenPalette(Data("nope".utf8), mode: "dark") == nil)
}
