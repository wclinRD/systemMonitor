import Foundation
import Combine

struct ProcessUsage: Identifiable {
    let id: Int // PID
    let name: String
    let uploadSpeed: Int64
    let downloadSpeed: Int64
}

class ProcessMonitor: ObservableObject, @unchecked Sendable {
    @Published var processes: [ProcessUsage] = []
    
    var topProcesses: [ProcessUsage] {
        processes.sorted { ($0.uploadSpeed + $0.downloadSpeed) > ($1.uploadSpeed + $1.downloadSpeed) }
    }
    
    private var process: Process?
    private var pipe: Pipe?
    
    // PID -> (BytesIn, BytesOut)
    private var previousUsage: [Int: (Int64, Int64)] = [:]
    
    // Temporary storage for current snapshot
    private var currentSnapshot: [ProcessUsage] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe interval changes
        PowerSavingManager.shared.$networkUpdateInterval
            .dropFirst() // establishing initial subscription shouldn't trigger
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Only restart if currently running
                if self.process != nil {
                    self.startMonitoring()
                }
            }
            .store(in: &cancellables)
            
        // Observe showTopProcesses changes
        UserDefaults.standard.publisher(for: \.showTopProcesses)
            .sink { [weak self] show in
                if show {
                    // removing this auto-start or logic might be complex if panel is closed
                    // relying on AppDelegate to call startMonitoring is better, 
                    // BUT if we are "running" (panel open) and user toggles this ON, we should start.
                    // However, we don't know if panel is open here easily without more coupling.
                    // For now: if turned OFF, stop. If ON, let AppDelegate/Panel logic handle start.
                    if !show {
                        self?.stopMonitoring()
                    }
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Prevent multiple processes
        stopMonitoring()
        
        // specific check: if user disabled top processes, do nothing
        guard UserDefaults.standard.bool(forKey: "showTopProcesses") else { return }
        
        let interval = PowerSavingManager.shared.networkUpdateInterval
        let intervalString = String(format: "%.0f", max(1.0, interval))
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
            // -P: Per process
            // -L 0: Infinite logging
            // -J: columns
            // -s: update interval (seconds)
            process.arguments = ["-P", "-L", "0", "-J", "bytes_in,bytes_out", "-s", intervalString]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            // Set reader on background queue to avoid main thread parsing
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let string = String(data: data, encoding: .utf8) {
                    self?.parseOutput(string)
                }
            }
            
            do {
                try process.run()
                
                // Update state on main actor if needed, but here we just store it
                // We use a lock or just insure we set it safely. 
                // Since this class is @unchecked Sendable but logic is simple:
                DispatchQueue.main.async {
                    self?.pipe = pipe
                    self?.process = process
                }
            } catch {
                print("Failed to start nettop: \(error)")
            }
        }
    }
    
    func stopMonitoring() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
    }
    
    private func parseOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // delimiter for new snapshot
            if trimmed.contains(",bytes_in,bytes_out,") {
                finishSnapshot()
                continue
            }
            
            let parts = trimmed.split(separator: ",")
            if parts.count >= 3 {
                let nameAndPid = String(parts[0])
                // Parse name and PID
                // Look for last dot
                if let lastDotIndex = nameAndPid.lastIndex(of: ".") {
                    let name = String(nameAndPid[..<lastDotIndex])
                    let pidString = String(nameAndPid[nameAndPid.index(after: lastDotIndex)...])
                    
                    if let pid = Int(pidString),
                       let bytesIn = Int64(parts[1]),
                       let bytesOut = Int64(parts[2]) {
                        
                        let (prevIn, prevOut) = previousUsage[pid] ?? (bytesIn, bytesOut)
                        
                        let speedIn = bytesIn - prevIn
                        let speedOut = bytesOut - prevOut
                        
                        // Update previous usage
                        previousUsage[pid] = (bytesIn, bytesOut)
                        
                        // Only add if there is activity (speed > 0)
                        if speedIn > 0 || speedOut > 0 {
                            let usage = ProcessUsage(
                                id: pid,
                                name: name,
                                uploadSpeed: speedOut,
                                downloadSpeed: speedIn
                            )
                            currentSnapshot.append(usage)
                        }
                    }
                }
            }
        }
    }
    
    private func finishSnapshot() {
        // Sort and publish
        let snapshot = currentSnapshot.sorted {
            ($0.downloadSpeed + $0.uploadSpeed) > ($1.downloadSpeed + $1.uploadSpeed)
        }
        
        DispatchQueue.main.async {
            self.processes = snapshot
        }
        
        currentSnapshot.removeAll()
    }
}

extension UserDefaults {
    @objc dynamic var showTopProcesses: Bool {
        return bool(forKey: "showTopProcesses")
    }
}
