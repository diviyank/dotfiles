import Foundation

public struct ProcessSample: Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuNanos: UInt64
    public let footprint: UInt64

    public init(pid: Int32, name: String, cpuNanos: UInt64, footprint: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuNanos = cpuNanos
        self.footprint = footprint
    }
}

public struct ProcessUsage: Equatable, Sendable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let footprint: UInt64
}

public enum ProcessOrder: Sendable { case cpu, memory }

public func topProcesses(
    previous: [Int32: ProcessSample], current: [ProcessSample], interval: TimeInterval, sortedBy order: ProcessOrder = .cpu, limit: Int = 5
) -> [ProcessUsage] {
    let usages = current.map { sample -> ProcessUsage in
        let before = previous[sample.pid]?.cpuNanos ?? sample.cpuNanos
        let delta = sample.cpuNanos >= before ? sample.cpuNanos - before : 0
        let percent = interval > 0 ? Double(delta) / (interval * 1e9) * 100 : 0
        return ProcessUsage(pid: sample.pid, name: sample.name, cpuPercent: percent, footprint: sample.footprint)
    }
    return Array(usages.sorted { lhs, rhs in
        switch order {
        case .cpu: lhs.cpuPercent != rhs.cpuPercent ? lhs.cpuPercent > rhs.cpuPercent : lhs.footprint > rhs.footprint
        case .memory: lhs.footprint != rhs.footprint ? lhs.footprint > rhs.footprint : lhs.cpuPercent > rhs.cpuPercent
        }
    }.prefix(limit))
}

public enum CPUState {
    public static let idle = 2
}

public func cpuBusyFraction(previous: [UInt64], current: [UInt64]) -> Double {
    guard previous.count == current.count, current.count > CPUState.idle else { return 0 }
    let deltas = zip(previous, current).map { $1 >= $0 ? $1 - $0 : 0 }
    let total = deltas.reduce(0, +)
    guard total > 0 else { return 0 }
    return Double(total - deltas[CPUState.idle]) / Double(total)
}

public func usedMemory(total: UInt64, free: UInt64, inactive: UInt64, speculative: UInt64) -> UInt64 {
    let available = free + inactive + speculative
    return total > available ? total - available : 0
}

public func formatBytes(_ bytes: UInt64) -> String {
    let mebibyte = 1_048_576.0
    let gibibyte = 1_073_741_824.0
    let value = Double(bytes)
    return value < gibibyte
        ? "\(Int(value / mebibyte)) MB"
        : String(format: "%.1f GB", value / gibibyte)
}
