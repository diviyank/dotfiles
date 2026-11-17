import Foundation
import ShellCore

@MainActor
final class WeatherService: ObservableObject {
    @Published private(set) var cache: WeatherCache?
    @Published private(set) var failed = false

    private var isFetching = false
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    func refreshIfStale(location: String) {
        if cache == nil { cache = Self.load() }
        let current = cache?.location == location ? cache : nil
        guard !isFetching, current?.coordinates == nil || isStale(current?.reading, now: Date()) else { return }
        isFetching = true
        Task {
            let fresh = await fetch(location: location, cached: current)
            isFetching = false
            failed = fresh?.reading == nil || isStale(fresh?.reading, now: Date())
            guard let fresh else { return }
            cache = fresh
            Self.save(fresh)
        }
    }

    private func fetch(location: String, cached: WeatherCache?) async -> WeatherCache? {
        var result = cached ?? WeatherCache(location: location, coordinates: nil, reading: nil)
        if result.coordinates == nil {
            guard let coordinates = await get(Self.geocodingURL(location)).flatMap(decodeGeocoding) else { return cached }
            result.coordinates = coordinates
        }
        guard let coordinates = result.coordinates else { return cached }
        guard let reading = await get(Self.forecastURL(coordinates)).flatMap({ decodeCurrentWeather($0, now: Date()) }) else {
            return result.coordinates == cached?.coordinates ? cached : result
        }
        result.reading = reading
        return result
    }

    private func get(_ url: URL?) async -> Data? {
        guard let url else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    private static func geocodingURL(_ location: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [URLQueryItem(name: "name", value: location), URLQueryItem(name: "count", value: "1")]
        return components?.url
    }

    private static func forecastURL(_ coordinates: Coordinates) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinates.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinates.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        return components?.url
    }

    private static func load() -> WeatherCache? {
        guard let data = try? Data(contentsOf: ShellPaths.weather) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeatherCache.self, from: data)
    }

    private static func save(_ cache: WeatherCache) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? FileManager.default.createDirectory(at: ShellPaths.weather.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: ShellPaths.weather, options: .atomic)
    }
}
