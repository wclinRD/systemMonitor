import Foundation
import SystemConfiguration

class NetworkMonitor: ObservableObject, @unchecked Sendable {
    @Published var uploadSpeed: Int64 = 0
    @Published var downloadSpeed: Int64 = 0
    @Published var uploadHistory: [Double] = Array(repeating: 0, count: 40)
    @Published var downloadHistory: [Double] = Array(repeating: 0, count: 40)
    
    // Session totals
    @Published var totalUpload: Int64 = 0
    @Published var totalDownload: Int64 = 0
    
    private var lastBytesIn: Int64 = 0
    private var lastBytesOut: Int64 = 0
    private var lastCheckTime: TimeInterval = 0
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Initialize baseline
        (lastBytesIn, lastBytesOut) = getGlobalBytes()
        lastCheckTime = Date().timeIntervalSince1970
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSpeed()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSpeed() {
        let (currentBytesIn, currentBytesOut) = getGlobalBytes()
        let currentTime = Date().timeIntervalSince1970
        
        let bytesInDiff = currentBytesIn - lastBytesIn
        let bytesOutDiff = currentBytesOut - lastBytesOut
        
        // Handle overflow or reset logic if needed, though Int64 is large enough
        if bytesInDiff >= 0 && bytesOutDiff >= 0 {
            DispatchQueue.main.async {
                self.downloadSpeed = bytesInDiff
                self.uploadSpeed = bytesOutDiff
                
                self.totalDownload += bytesInDiff
                self.totalUpload += bytesOutDiff
                
                // Update history (shift left)
                self.downloadHistory.removeFirst()
                self.downloadHistory.append(Double(bytesInDiff))
                
                self.uploadHistory.removeFirst()
                self.uploadHistory.append(Double(bytesOutDiff))
            }
        }
        
        lastBytesIn = currentBytesIn
        lastBytesOut = currentBytesOut
        lastCheckTime = currentTime
    }
    
    // Based on getifaddrs
    private func getGlobalBytes() -> (Int64, Int64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        var totalBytesIn: Int64 = 0
        var totalBytesOut: Int64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            // AF_LINK is for link layer interface data
            // We want to skip loopback "lo0" generally, but user might want total.
            // Usually we filter for "en0" or exclude "lo0". Let's exclude "lo0".
            let name = String(cString: interface.ifa_name)
            
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if !name.hasPrefix("lo") { // Exclude loopback
                    let data = unsafeBitCast(interface.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                    totalBytesIn += Int64(data.pointee.ifi_ibytes)
                    totalBytesOut += Int64(data.pointee.ifi_obytes)
                }
            }
            
            ptr = interface.ifa_next
        }
        
        return (totalBytesIn, totalBytesOut)
    }
}
