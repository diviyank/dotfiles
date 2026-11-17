import Foundation
import Testing
@testable import ShellCore

private let geocodingFixture = Data("""
{"results":[{"id":2988507,"name":"Paris","latitude":48.85341,"longitude":2.3488,"elevation":42.0,"feature_code":"PPLC","country_code":"FR","timezone":"Europe/Paris","country":"France"}],"generationtime_ms":0.6}
""".utf8)

private let forecastFixture = Data("""
{"latitude":48.86,"longitude":2.3399997,"generationtime_ms":0.02,"utc_offset_seconds":0,"timezone":"GMT","current_units":{"time":"iso8601","interval":"seconds","temperature_2m":"°C","weather_code":"wmo code"},"current":{"time":"2026-11-17T11:00","interval":900,"temperature_2m":9.3,"weather_code":2}}
""".utf8)

@Test func decodesGeocoding() {
    #expect(decodeGeocoding(geocodingFixture) == Coordinates(name: "Paris", latitude: 48.85341, longitude: 2.3488))
}

@Test func decodesCurrentWeather() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(decodeCurrentWeather(forecastFixture, now: now) == WeatherReading(temperature: 9.3, code: 2, fetchedAt: now))
}

@Test func rejectsBadWeatherPayloads() {
    #expect(decodeGeocoding(Data("garbage".utf8)) == nil)
    #expect(decodeGeocoding(Data(#"{"generationtime_ms":0.1}"#.utf8)) == nil)
    #expect(decodeGeocoding(Data(#"{"results":[]}"#.utf8)) == nil)
    #expect(decodeCurrentWeather(Data(#"{"latitude":1}"#.utf8), now: Date()) == nil)
}

@Test func weatherLookGroups() {
    let cases: [(Int, String, String)] = [
        (0, Glyph.clearDay, "Clear"), (2, Glyph.partlyCloudyDay, "Partly cloudy"), (3, Glyph.cloud, "Cloudy"),
        (45, Glyph.foggy, "Fog"), (61, Glyph.rainy, "Rain"), (81, Glyph.rainy, "Rain"),
        (73, Glyph.snowy, "Snow"), (86, Glyph.snowy, "Snow"), (96, Glyph.thunderstorm, "Thunderstorm"),
        (42, Glyph.cloud, "Unknown"),
    ]
    for (code, glyph, text) in cases {
        let look = weatherLook(code: code)
        #expect(look.glyph == glyph && look.text == text, "code \(code)")
    }
}

@Test func staleness() {
    let now = Date(timeIntervalSince1970: 10_000)
    #expect(isStale(nil, now: now))
    #expect(!isStale(WeatherReading(temperature: 1, code: 0, fetchedAt: now.addingTimeInterval(-899)), now: now))
    #expect(isStale(WeatherReading(temperature: 1, code: 0, fetchedAt: now.addingTimeInterval(-900)), now: now))
}

@Test func ageTexts() {
    let now = Date(timeIntervalSince1970: 100_000)
    #expect(ageText(since: now.addingTimeInterval(-30), now: now) == "now")
    #expect(ageText(since: now.addingTimeInterval(-25 * 60), now: now) == "25 min ago")
    #expect(ageText(since: now.addingTimeInterval(-3 * 3600 - 60), now: now) == "3 h ago")
}

@Test func weatherCacheRoundTrips() throws {
    let cache = WeatherCache(
        location: "Paris",
        coordinates: Coordinates(name: "Paris", latitude: 48.85341, longitude: 2.3488),
        reading: WeatherReading(temperature: 9.3, code: 2, fetchedAt: Date(timeIntervalSince1970: 1_000))
    )
    let data = try JSONEncoder().encode(cache)
    #expect(try JSONDecoder().decode(WeatherCache.self, from: data) == cache)
}
