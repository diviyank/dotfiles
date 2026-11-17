import ShellCore
import SwiftUI

struct PerformanceCard: View {
    @ObservedObject var model: BarModel
    @ObservedObject var sampler: PerformanceSampler

    private static let alarm = 0.85

    var body: some View {
        DashboardCard(model: model) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack(spacing: Theme.Spacing.medium) {
                    meter("CPU", value: "\(Int(sampler.cpu * 100))%", fraction: sampler.cpu)
                    meter("RAM", value: memoryText, fraction: memoryFraction)
                    meter("Disk", value: "\(Int(sampler.diskFraction * 100))%", fraction: sampler.diskFraction)
                }
                processTable
            }
        }
    }

    private var memoryFraction: Double {
        sampler.memoryTotal == 0 ? 0 : Double(sampler.memoryUsed) / Double(sampler.memoryTotal)
    }

    private var memoryText: String {
        let gib = 1_073_741_824.0
        return String(format: "%.1f/%.0f GB", Double(sampler.memoryUsed) / gib, Double(sampler.memoryTotal) / gib)
    }

    private func meter(_ label: String, value: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Theme.Spacing.extraSmall) {
                Text(label).font(Font(Theme.text(Theme.Dashboard.smallText)))
                Text(value)
                    .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.smallText)))
                    .foregroundStyle(model.color("primary"))
            }
            Capsule()
                .fill(model.color("surface_container_highest"))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(model.color(fraction > Self.alarm ? "error" : "primary"))
                            .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                    }
                }
        }
        .foregroundStyle(model.color("on_surface"))
        .frame(maxWidth: .infinity)
    }

    private var processTable: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.small, verticalSpacing: 1) {
            GridRow {
                header("PID")
                header("Process")
                sortHeader("CPU", .cpu).gridColumnAlignment(.trailing)
                sortHeader("RAM", .memory).gridColumnAlignment(.trailing)
            }
            ForEach(sampler.top, id: \.pid) { process in
                GridRow {
                    number("\(process.pid)")
                    Text(process.name)
                        .font(Font(Theme.text(Theme.Dashboard.smallText)))
                        .foregroundStyle(model.color("on_surface"))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    number("\(Int(process.cpuPercent.rounded()))%", alarm: process.cpuPercent > 100)
                    number(formatBytes(process.footprint))
                }
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(Font(Theme.text(Theme.Dashboard.smallText)))
            .foregroundStyle(model.color("outline"))
    }

    private func sortHeader(_ text: String, _ order: ProcessOrder) -> some View {
        Text(text)
            .font(Font(Theme.text(Theme.Dashboard.smallText, weight: sampler.order == order ? .medium : .regular)))
            .foregroundStyle(model.color(sampler.order == order ? "primary" : "outline"))
            .contentShape(Rectangle())
            .onTapGesture { sampler.order = order }
    }

    private func number(_ text: String, alarm: Bool = false) -> some View {
        Text(text)
            .font(Font(Theme.font(Theme.Family.numbers, size: Theme.Dashboard.smallText)))
            .foregroundStyle(model.color(alarm ? "error" : "on_surface"))
            .monospacedDigit()
    }
}
