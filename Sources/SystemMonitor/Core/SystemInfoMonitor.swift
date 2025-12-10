import Foundation
import Combine
import Darwin

class SystemInfoMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsed: Int64 = 0
    @Published var memoryTotal: Int64 = 0
    @Published var diskUsed: Int64 = 0
    @Published var diskTotal: Int64 = 0
    
    private var timer: Timer?
    private var lastCPULoadInfo: host_cpu_load_info?
    
    init() {
        // Initial fetch
        memoryTotal = getTotalMemory()
        updateInfo()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateInfo()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateInfo() {
        self.cpuUsage = getCPUUsage()
        self.memoryUsed = getMemoryUsage()
        
        let (dUsed, dTotal) = getDiskUsage()
        self.diskUsed = dUsed
        self.diskTotal = dTotal
    }
    
    // MARK: - CPU
    private func getCPUUsage() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        var usage: Double = 0
        
        if let last = lastCPULoadInfo {
            let userDiff = Double(info.cpu_ticks.0 - last.cpu_ticks.0)
            let systemDiff = Double(info.cpu_ticks.1 - last.cpu_ticks.1)
            let idleDiff = Double(info.cpu_ticks.2 - last.cpu_ticks.2)
            let niceDiff = Double(info.cpu_ticks.3 - last.cpu_ticks.3)
            
            let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
            if totalTicks > 0 {
                usage = (userDiff + systemDiff + niceDiff) / totalTicks
            }
        }
        
        lastCPULoadInfo = info
        return usage
    }
    
    // MARK: - Memory
    private func getTotalMemory() -> Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }
    
    private func getMemoryUsage() -> Int64 {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let pageSize = getPageSize()
        // Activity Monitor "Memory Used" ≈ Total - Free - Inactive - Speculative - Purgeable
        // Alternative: App Memory + Wired + Compressed
        // Using: Total - (free + inactive + speculative + purgeable_external)
        let freePages = Int64(info.free_count + info.inactive_count + info.speculative_count + info.purgeable_count)
        let used = memoryTotal - (freePages * pageSize)
        return max(0, used)
    }
    
    private func getPageSize() -> Int64 {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        return Int64(pageSize)
    }
    
    // MARK: - Disk
    private func getDiskUsage() -> (Int64, Int64) {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = attributes[.systemSize] as? Int64 ?? 0
            let free = attributes[.systemFreeSize] as? Int64 ?? 0
            let used = total - free
            return (used, total)
        } catch {
            return (0, 0)
        }
    }
}
