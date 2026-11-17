import Darwin
import Foundation
import ShellCore

struct PerformanceSnapshot: Sendable {
    let cpu: Double
    let memoryUsed: UInt64
    let diskFraction: Double
    let topByCPU: [ProcessUsage]?
    let topByMemory: [ProcessUsage]?
}

@MainActor
final class PerformanceSampler: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var diskFraction: Double = 0
    @Published private(set) var topByCPU: [ProcessUsage] = []
    @Published private(set) var topByMemory: [ProcessUsage] = []
    @Published var order = ProcessOrder.cpu
    var top: [ProcessUsage] { order == .cpu ? topByCPU : topByMemory }
    let memoryTotal = ProcessInfo.processInfo.physicalMemory

    private static let interval: TimeInterval = 3
    private static let warmUp: TimeInterval = 0.5
    private let queue = DispatchQueue(label: "local.celestia.shell.performance", qos: .utility)
    private let probe = SystemProbe()
    private var timer: DispatchSourceTimer?

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.interval)
        timer.setEventHandler { [probe, weak self] in
            let snapshot = probe.sample()
            Task { @MainActor in self?.apply(snapshot) }
        }
        timer.resume()
        self.timer = timer
        queue.asyncAfter(deadline: .now() + Self.warmUp) { [probe, weak self] in
            let snapshot = probe.sample()
            Task { @MainActor in self?.apply(snapshot) }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async { [probe] in probe.reset() }
        topByCPU = []
        topByMemory = []
        order = .cpu
    }

    private func apply(_ snapshot: PerformanceSnapshot) {
        guard timer != nil else { return }
        cpu = snapshot.cpu
        memoryUsed = snapshot.memoryUsed
        diskFraction = snapshot.diskFraction
        if let processes = snapshot.topByCPU { topByCPU = processes }
        if let processes = snapshot.topByMemory { topByMemory = processes }
    }
}

final class SystemProbe: @unchecked Sendable {
    private var previousProcesses: [Int32: ProcessSample] = [:]
    private var previousTicks: [UInt64] = []
    private var previousTime: UInt64 = 0
    private let nanosPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    func reset() {
        previousProcesses = [:]
        previousTicks = []
        previousTime = 0
    }

    func sample() -> PerformanceSnapshot {
        let now = mach_absolute_time()
        let ticks = cpuTicks()
        let processes = processSamples()
        let cpu = previousTicks.isEmpty ? 0 : cpuBusyFraction(previous: previousTicks, current: ticks)
        var byCPU: [ProcessUsage]?
        var byMemory: [ProcessUsage]?
        if previousTime != 0 {
            let interval = Double(now - previousTime) * nanosPerTick / 1e9
            byCPU = topProcesses(previous: previousProcesses, current: processes, interval: interval)
            byMemory = topProcesses(previous: previousProcesses, current: processes, interval: interval, sortedBy: .memory)
        }
        previousTicks = ticks
        previousTime = now
        previousProcesses = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { $1 })
        return PerformanceSnapshot(cpu: cpu, memoryUsed: memoryInUse(), diskFraction: diskUsage(), topByCPU: byCPU, topByMemory: byMemory)
    }

    private func cpuTicks() -> [UInt64] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info
        else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        var totals = [UInt64](repeating: 0, count: states)
        for cpu in 0..<Int(cpuCount) {
            for state in 0..<states {
                totals[state] += UInt64(UInt32(bitPattern: info[cpu * states + state]))
            }
        }
        return totals
    }

    private func memoryInUse() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_kernel_page_size)
        return usedMemory(
            total: ProcessInfo.processInfo.physicalMemory,
            free: UInt64(stats.free_count) * page,
            inactive: UInt64(stats.inactive_count) * page,
            speculative: UInt64(stats.speculative_count) * page
        )
    }

    private func diskUsage() -> Double {
        var stats = statfs()
        guard statfs("/System/Volumes/Data", &stats) == 0, stats.f_blocks > 0 else { return 0 }
        return 1 - Double(stats.f_bavail) / Double(stats.f_blocks)
    }

    private func processSamples() -> [ProcessSample] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard found > 0 else { return [] }
        return pids.prefix(Int(found)).compactMap(sample(pid:))
    }

    private func sample(pid: Int32) -> ProcessSample? {
        guard pid > 0 else { return nil }
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        var name = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &name, UInt32(name.count)) > 0 else { return nil }
        let ticks = Double(usage.ri_user_time + usage.ri_system_time)
        return ProcessSample(
            pid: pid,
            name: String(cString: name),
            cpuNanos: UInt64(ticks * nanosPerTick),
            footprint: usage.ri_phys_footprint
        )
    }
}
