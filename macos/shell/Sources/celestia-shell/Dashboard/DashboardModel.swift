import Foundation
import ShellCore

@MainActor
final class DashboardModel: ObservableObject {
    let performance = PerformanceSampler()
    let calendar = CalendarStore()
    let weather = WeatherService()
    let spotify = SpotifySensor()
    private let settings: () -> ShellSettings

    init(settings: @escaping () -> ShellSettings) {
        self.settings = settings
    }

    func opened() {
        performance.start()
        calendar.start()
        spotify.start()
        weather.refreshIfStale(location: settings().weatherLocation)
    }

    func closed() {
        performance.stop()
        calendar.stop()
        spotify.stop()
    }
}
