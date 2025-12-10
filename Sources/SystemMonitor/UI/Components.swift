import SwiftUI

// MARK: - Circular Progress Ring
struct CircularProgressView: View {
    let progress: Double // 0.0 - 1.0
    let color: Color
    let lineWidth: CGFloat
    
    init(progress: Double, color: Color, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - System Card (for Grid)
struct SystemCard<Content: View>: View {
    let opacity: Double
    let content: Content
    
    init(opacity: Double = 1.0, @ViewBuilder content: () -> Content) {
        self.opacity = opacity
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(minHeight: 140)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(opacity))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - CPU Card
struct CPUCardView: View {
    let usage: Double
    let chipName: String
    var cardOpacity: Double = 1.0
    
    var body: some View {
        SystemCard(opacity: cardOpacity) {
            VStack(spacing: 8) {
                // Icon in top-right
                HStack {
                    Spacer()
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Circular Progress
                ZStack {
                    CircularProgressView(progress: usage, color: .green)
                        .frame(width: 60, height: 60)
                    
                    Text("\(Int(usage * 100))%")
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Label
                HStack(spacing: 4) {
                    Image(systemName: "desktopcomputer")
                        .font(.caption2)
                    Text("CPU LOAD")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
                
                Text(chipName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Memory Card
struct MemoryCardView: View {
    let used: Int64
    let total: Int64
    var cardOpacity: Double = 1.0
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var body: some View {
        SystemCard(opacity: cardOpacity) {
            VStack(spacing: 8) {
                // Icon in top-right
                HStack {
                    Spacer()
                    Image(systemName: "memorychip")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Circular Progress
                ZStack {
                    CircularProgressView(progress: progress, color: .green)
                        .frame(width: 60, height: 60)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Label
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.caption2)
                    Text("MEMORY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
                
                Text("\(formatBytes(used)) of \(formatBytes(total))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 150)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }
}

// MARK: - Disk Card
struct DiskCardView: View {
    let used: Int64
    let total: Int64
    let diskName: String
    var cardOpacity: Double = 1.0
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var body: some View {
        SystemCard(opacity: cardOpacity) {
            VStack(spacing: 8) {
                // Icon in top-right
                HStack {
                    Spacer()
                    Image(systemName: "externaldrive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Percentage
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                
                // Progress Bar
                ProgressBar(value: progress, color: .green)
                    .frame(height: 6)
                
                // Label
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                    Text(diskName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
                
                Text("\(formatBytes(used)) of \(formatBytes(total))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 150)
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }
}

// MARK: - Thermal State Card
struct ThermalStateCardView: View {
    var temperature: Double = 0.0  // °C
    var cardOpacity: Double = 1.0
    
    var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    var stateText: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    var stateColor: Color {
        switch thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
    
    var progress: Double {
        // Map temperature to progress (0-100°C range)
        return min(max(temperature / 100.0, 0.1), 1.0)
    }
    
    var body: some View {
        SystemCard(opacity: cardOpacity) {
            VStack(spacing: 8) {
                // Icon in top-right
                HStack {
                    Spacer()
                    Image(systemName: "thermometer.medium")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Circular Progress with Temperature
                ZStack {
                    CircularProgressView(progress: progress, color: stateColor)
                        .frame(width: 60, height: 60)
                    
                    Text("\(Int(temperature))°")
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Label
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text("THERMAL")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
                
                Text(stateText)
                    .font(.caption2)
                    .foregroundColor(stateColor)
            }
        }
    }
}

// MARK: - Progress Bar (Horizontal)
struct ProgressBar: View {
    let value: Double // 0.0 - 1.0
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, min(geometry.size.width * CGFloat(value), geometry.size.width)), height: 6)
            }
        }
        .frame(height: 6)
    }
}
