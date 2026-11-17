import CoreText
import Foundation
import Testing
@testable import ShellCore

@Test func batteryGlyphs() {
    #expect(batteryGlyph(percent: 100, charging: false) == Glyph.batteryFull)
    #expect(batteryGlyph(percent: 100, charging: true) == Glyph.batteryChargingFull)
    #expect(batteryGlyph(percent: 50, charging: false) == Glyph.batteryBars[3])
    #expect(batteryGlyph(percent: 5, charging: false) == Glyph.batteryBars[0])
}

@Test func volumeGlyphs() {
    #expect(volumeGlyph(percent: 80, muted: true) == Glyph.volumeOff)
    #expect(volumeGlyph(percent: 50, muted: false) == Glyph.volumeUp)
    #expect(volumeGlyph(percent: 10, muted: false) == Glyph.volumeDown)
    #expect(volumeGlyph(percent: 0, muted: false) == Glyph.volumeMute)
}

@Test func wifiGlyphs() {
    #expect(wifiGlyph(rssi: nil) == Glyph.wifiOff)
    #expect(wifiGlyph(rssi: -50) == Glyph.wifi)
    #expect(wifiGlyph(rssi: -60) == Glyph.wifi3Bar)
    #expect(wifiGlyph(rssi: -70) == Glyph.wifi2Bar)
    #expect(wifiGlyph(rssi: -80) == Glyph.wifi1Bar)
}

@Test func statusLabelParsed() {
    #expect(parseStatusLabel(#""StatusLabel"={ "label"="3" }"#) == "3")
    #expect(parseStatusLabel(#""StatusLabel"={ "label"="•" }"#) == "•")
    #expect(parseStatusLabel(#""StatusLabel"=[ NULL ]"#) == nil)
    #expect(parseStatusLabel(#""StatusLabel"={ "label"="" }"#) == nil)
    #expect(parseStatusLabel("") == nil)
}

private func shapedGlyphs(_ text: String, _ font: CTFont) -> [CGGlyph] {
    let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    return (CTLineGetGlyphRuns(line) as! [CTRun]).flatMap { run -> [CGGlyph] in
        var glyphs = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        return glyphs
    }
}

@Test func glyphCodepointsMatchTheirNames() throws {
    let font = CTFontCreateWithName("Material Symbols Rounded" as CFString, 20, nil)
    try #require(CTFontCopyFamilyName(font) as String == "Material Symbols Rounded")
    for (name, glyph) in Glyph.named {
        let byName = shapedGlyphs(name, font)
        let byCodepoint = shapedGlyphs(glyph, font)
        #expect(byName.count == 1 && byName == byCodepoint, "\(name) is not U+\(String(glyph.unicodeScalars.first!.value, radix: 16, uppercase: true))")
    }
}
