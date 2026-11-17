import Foundation

public struct ShellSettings: Equatable, Sendable {
    public var border: Double
    public var weatherLocation: String

    public static let defaults = ShellSettings(border: 6, weatherLocation: "Paris")
}

public func loadSettings(_ url: URL) -> ShellSettings {
    var settings = ShellSettings.defaults
    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return settings }
    if let border = json["border"] as? Double, border >= 0 {
        settings.border = border
    }
    if let weather = json["weather"] as? [String: Any], let location = weather["location"] as? String, !location.isEmpty {
        settings.weatherLocation = location
    }
    return settings
}
