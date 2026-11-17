import Foundation

@MainActor
final class DashboardModel: ObservableObject {
    let performance = PerformanceSampler()
    let calendar = CalendarStore()

    func opened() {
        performance.start()
        calendar.start()
    }

    func closed() {
        performance.stop()
        calendar.stop()
    }
}
