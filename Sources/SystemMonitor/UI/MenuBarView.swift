import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var networkMonitor: NetworkMonitor
    @ObservedObject var processMonitor: ProcessMonitor
    @ObservedObject var systemInfo: SystemInfoMonitor
    @ObservedObject var temperatureMonitor: TemperatureMonitor
    @ObservedObject private var localization = LocalizationManager.shared
    
    @AppStorage("menuBarWidth") private var menuBarWidth = 340.0
    @AppStorage("menuBarOpacity") private var menuBarOpacity = 0.8
    @AppStorage("cardOpacity") private var cardOpacity = 1.0
    @AppStorage("appDisplayCount") private var appDisplayCount = 5
    @AppStorage("appListStyle") private var appListStyle = "Icon + Name"
    @AppStorage("uploadColor") private var uploadColorHex = "#007AFF"
    @AppStorage("downloadColor") private var downloadColorHex = "#34C759"
    @AppStorage("showTopProcesses") private var showTopProcesses = true
    
    var uploadColor: Color { Color(hex: uploadColorHex) }
    var downloadColor: Color { Color(hex: downloadColorHex) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("System Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 2x2 Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                // CPU
                CPUCardView(
                    usage: systemInfo.cpuUsage,
                    chipName: "Apple M4 Pro", // TODO: Get real chip name
                    cardOpacity: cardOpacity
                )
                
                // Memory
                MemoryCardView(
                    used: systemInfo.memoryUsed,
                    total: systemInfo.memoryTotal,
                    cardOpacity: cardOpacity
                )
                
                // Disk
                DiskCardView(
                    used: systemInfo.diskUsed,
                    total: systemInfo.diskTotal,
                    diskName: "Macintosh HD",
                    cardOpacity: cardOpacity
                )
                
                // Thermal State with Temperature
                ThermalStateCardView(
                    temperature: temperatureMonitor.cpuTemperature,
                    cardOpacity: cardOpacity
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if showTopProcesses {
                Divider()
                    .padding(.vertical, 8)
                
                // Top 2 Uploading Apps
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Upload".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    let topUploading = processMonitor.processes
                        .filter { $0.uploadSpeed > 0 }
                        .sorted { $0.uploadSpeed > $1.uploadSpeed }
                        .prefix(2)
                    
                    if topUploading.isEmpty {
                        Text("—".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(Array(topUploading)) { process in
                            ProcessRow(process: process, mode: .upload, color: .primary, listStyle: appListStyle, uploadColor: uploadColor, downloadColor: downloadColor)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Top 2 Downloading Apps
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Download".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    let topDownloading = processMonitor.processes
                        .filter { $0.downloadSpeed > 0 }
                        .sorted { $0.downloadSpeed > $1.downloadSpeed }
                        .prefix(2)
                    
                    if topDownloading.isEmpty {
                        Text("—".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(Array(topDownloading)) { process in
                            ProcessRow(process: process, mode: .download, color: .primary, listStyle: appListStyle, uploadColor: uploadColor, downloadColor: downloadColor)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Footer
            HStack {
                Button(action: {
                    showTopProcesses.toggle()
                }) {
                    Image(systemName: showTopProcesses ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(showTopProcesses ? "Hide Top Processes" : "Show Top Processes")
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: CGFloat(menuBarWidth))
        .background(Color(nsColor: .windowBackgroundColor).opacity(menuBarOpacity))
    }
    
    func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

struct ProcessRow: View {
    enum SpeedMode { case upload, download }
    
    let process: ProcessUsage
    var mode: SpeedMode = .download
    let color: Color
    let listStyle: String
    var uploadColor: Color = .green
    var downloadColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 8) {
            if listStyle.contains("Icon") {
                AppIconView(pid: process.id)
                    .frame(width: 20, height: 20)
            }
            
            if listStyle.contains("Name") {
                AppNameView(pid: process.id, fallbackName: process.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Show speed based on mode with user's color settings
            if mode == .upload {
                Text("↑\(SpeedFormatter.format(process.uploadSpeed))")
                    .foregroundColor(uploadColor)
                    .font(.caption)
                    .fixedSize()
            } else {
                Text("↓\(SpeedFormatter.format(process.downloadSpeed))")
                    .foregroundColor(downloadColor)
                    .font(.caption)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct AppNameView: View {
    let pid: Int
    let fallbackName: String
    @State private var displayName: String = ""
    
    var body: some View {
        Text(displayName.isEmpty ? fallbackName : displayName)
            .lineLimit(1)
            .foregroundColor(.primary)
            .onAppear {
                if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                    displayName = app.localizedName ?? fallbackName
                }
            }
    }
}

struct AppIconView: View {
    let pid: Int
    @State private var icon: NSImage?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                 Color.clear.frame(width: 16, height: 16)
            }
        }
        .onAppear {
            if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                self.icon = app.icon
            }
        }
    }
}
