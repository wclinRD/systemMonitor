import Foundation
import Combine
import Darwin

class SystemInfoMonitor: ObservableObject, @unchecked Sendable {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsed: Int64 = 0
    @Published var memoryTotal: Int64 = 0
    @Published var diskUsed: Int64 = 0
    @Published var diskTotal: Int64 = 0
    
    private var timer: DispatchSourceTimer?
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
        guard timer == nil else { return }
        
        let settings = PowerSavingManager.shared
        let interval = settings.systemInfoUpdateInterval
        
        timer = settings.createTimer(interval: interval) { [weak self] in
            self?.updateInfo()
        }
        timer?.resume()
    }
    
    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }
    
    private func updateInfo() {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        let (dUsed, dTotal) = getDiskUsage()
        
        DispatchQueue.main.async {
            self.cpuUsage = cpu
            self.memoryUsed = memory
            self.diskUsed = dUsed
            self.diskTotal = dTotal
        }
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
        
        // Activity Monitor "Memory Used" = App Memory + Wired + Compressed
        // App Memory ≈ active + internal (which is roughly total - free - inactive - speculative - purgeable - wired - compressed)
        // We use: Active + Wired + Compressed + (Wire + internal overhead)
        // Simpler: Total - Free - Inactive - Speculative - File-backed purgeable
        // Best approximation: (total pages - free - inactive - speculative - external) * pageSize
        // But Activity Monitor calculates: wired + app memory + compressed
        
        // Matching Activity Monitor more closely:
        // App Memory = internal pages (not directly available, but ≈ active - external)
        // Wired = wire_count
        // Compressed = compressor_page_count
        let wired = Int64(info.wire_count) * pageSize
        let compressed = Int64(info.compressor_page_count) * pageSize
        let active = Int64(info.active_count) * pageSize
        
        // App Memory ≈ internal_page_count (system internal) + active external handling
        // For simplicity: wired + compressed + (active pages that aren't file-cached)
        // Most accurate: use internal_page_count if available
        let internalPages = Int64(info.internal_page_count) * pageSize
        
        // Memory Used = App Memory + Wired + Compressed
        // App Memory ≈ internal - purgeable
        let purgeable = Int64(info.purgeable_count) * pageSize
        let appMemory = internalPages - purgeable
        
        let used = appMemory + wired + compressed
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
