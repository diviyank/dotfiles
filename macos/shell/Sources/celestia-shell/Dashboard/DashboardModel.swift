import Foundation

@MainActor
final class DashboardModel: ObservableObject {
    let performance = PerformanceSampler()

    func opened() {
        performance.start()
    }

    func closed() {
        performance.stop()
    }
}
