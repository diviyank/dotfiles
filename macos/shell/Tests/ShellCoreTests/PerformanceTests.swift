import Foundation
import Testing
@testable import ShellCore

private func sample(_ pid: Int32, _ cpuNanos: UInt64, footprint: UInt64 = 0) -> ProcessSample {
    ProcessSample(pid: pid, name: "p\(pid)", cpuNanos: cpuNanos, footprint: footprint)
}

@Test func topProcessesRanksByCPU() {
    let previous = Dictionary(uniqueKeysWithValues: (Int32(1)...7).map { ($0, sample($0, 1_000_000_000)) })
    let current = [
        sample(1, 1_000_000_000 + 3_480_000_000),
        sample(2, 1_000_000_000 + 200_000_000),
        sample(3, 1_000_000_000 + 1_000_000_000),
        sample(4, 1_000_000_000, footprint: 900),
        sample(5, 1_000_000_000 + 50_000_000),
        sample(6, 1_000_000_000, footprint: 100),
        sample(7, 1_000_000_000 + 10_000_000),
    ]
    let top = topProcesses(previous: previous, current: current, interval: 2)
    #expect(top.map { $0.pid } == [1, 3, 2, 5, 7])
    #expect(abs(top[0].cpuPercent - 174.0) < 0.001)
}

@Test func topProcessesBreaksTiesByFootprint() {
    let top = topProcesses(previous: [:], current: [sample(1, 5, footprint: 10), sample(2, 5, footprint: 20)], interval: 2)
    #expect(top.map { $0.pid } == [2, 1])
}

@Test func topProcessesHandlesExitAndReuse() {
    let previous: [Int32: ProcessSample] = [1: sample(1, 5_000_000_000), 2: sample(2, 9_000_000_000)]
    let current = [sample(2, 1_000_000_000), sample(3, 7_000_000_000)]
    let top = topProcesses(previous: previous, current: current, interval: 2)
    #expect(Set(top.map { $0.pid }) == [2, 3])
    #expect(top.allSatisfy { $0.cpuPercent == 0 })
}

@Test func cpuBusyFractionFromTicks() {
    #expect(cpuBusyFraction(previous: [10, 10, 80, 0], current: [40, 20, 130, 10]) == 0.5)
}

@Test func cpuBusyFractionZeroDelta() {
    #expect(cpuBusyFraction(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]) == 0)
}

@Test func usedMemoryClamps() {
    #expect(usedMemory(total: 8, free: 2, inactive: 1, speculative: 1) == 4)
    #expect(usedMemory(total: 8, free: 6, inactive: 2, speculative: 1) == 0)
}

@Test func formatBytesUnits() {
    #expect(formatBytes(62_914_560) == "60 MB")
    #expect(formatBytes(7_408_779_264) == "6.9 GB")
}

@Test func topProcessesRanksByMemory() {
    let current = [sample(1, 9_000_000_000, footprint: 10), sample(2, 0, footprint: 300), sample(3, 0, footprint: 200)]
    let top = topProcesses(previous: [:], current: current, interval: 2, sortedBy: .memory, limit: 2)
    #expect(top.map { $0.pid } == [2, 3])
}
