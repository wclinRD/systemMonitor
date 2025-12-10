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
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        // -P: Per process
        // -L 0: Infinite logging
        // -J: columns
        process.arguments = ["-P", "-L", "0", "-J", "bytes_in,bytes_out"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        self.pipe = pipe
        self.process = process
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let string = String(data: data, encoding: .utf8) {
                self?.parseOutput(string)
            }
        }
        
        do {
            try process.run()
        } catch {
            print("Failed to start nettop: \(error)")
        }
    }
    
    func stopMonitoring() {
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
