import Foundation

public struct Coordinates: Codable, Equatable, Sendable {
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct WeatherReading: Codable, Equatable, Sendable {
    public let temperature: Double
    public let code: Int
    public let fetchedAt: Date

    public init(temperature: Double, code: Int, fetchedAt: Date) {
        self.temperature = temperature
        self.code = code
        self.fetchedAt = fetchedAt
    }
}

public struct WeatherCache: Codable, Equatable, Sendable {
    public var location: String
    public var coordinates: Coordinates?
    public var reading: WeatherReading?

    public init(location: String, coordinates: Coordinates?, reading: WeatherReading?) {
        self.location = location
        self.coordinates = coordinates
        self.reading = reading
    }
}

private struct GeocodingResponse: Decodable {
    let results: [Coordinates]?
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
    }
    let current: Current
}

public func decodeGeocoding(_ data: Data) -> Coordinates? {
    (try? JSONDecoder().decode(GeocodingResponse.self, from: data))?.results?.first
}

public func decodeCurrentWeather(_ data: Data, now: Date) -> WeatherReading? {
    guard let current = (try? JSONDecoder().decode(ForecastResponse.self, from: data))?.current else { return nil }
    return WeatherReading(temperature: current.temperature_2m, code: current.weather_code, fetchedAt: now)
}

public func weatherLook(code: Int) -> (glyph: String, text: String) {
    switch code {
    case 0: (Glyph.clearDay, "Clear")
    case 1, 2: (Glyph.partlyCloudyDay, "Partly cloudy")
    case 3: (Glyph.cloud, "Cloudy")
    case 45, 48: (Glyph.foggy, "Fog")
    case 51...67, 80...82: (Glyph.rainy, "Rain")
    case 71...77, 85, 86: (Glyph.snowy, "Snow")
    case 95...99: (Glyph.thunderstorm, "Thunderstorm")
    default: (Glyph.cloud, "Unknown")
    }
}

public func isStale(_ reading: WeatherReading?, now: Date, maxAge: TimeInterval = 900) -> Bool {
    guard let reading else { return true }
    return now.timeIntervalSince(reading.fetchedAt) >= maxAge
}

public func ageText(since: Date, now: Date) -> String {
    let seconds = Int(now.timeIntervalSince(since))
    if seconds < 60 { return "now" }
    if seconds < 3600 { return "\(seconds / 60) min ago" }
    return "\(seconds / 3600) h ago"
}
