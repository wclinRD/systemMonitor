import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @ObservedObject private var localization = LocalizationManager.shared
    
    enum SettingsTab {
        case general
        case menuBar
        case panel
        case about
        
        @MainActor
        var title: String {
            switch self {
            case .general: return "General".localized
            case .menuBar: return "Menu Bar".localized
            case .panel: return "Panel".localized
            case .about: return "About".localized
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text("System Monitor".localized)
                    .font(.system(size: 24, weight: .bold))
                    // Remove lineSpacing constraint if it causes issues, but 0 is usually fine
                    .padding(.horizontal, 16)
                    .padding(.top, 40) // Space for traffic lights
                    .padding(.bottom, 20)
                
                // Navigation
                VStack(spacing: 4) {
                    SidebarButton(title: "General".localized, icon: "gearshape", isSelected: selectedTab == .general) {
                        selectedTab = .general
                    }
                    
                    SidebarButton(title: "Menu Bar".localized, icon: "menubar.rectangle", isSelected: selectedTab == .menuBar) {
                        selectedTab = .menuBar
                    }
                    
                    SidebarButton(title: "Panel".localized, icon: "rectangle.tophalf.inset.filled", isSelected: selectedTab == .panel) {
                        selectedTab = .panel
                    }
                    
                    SidebarButton(title: "About".localized, icon: "info.circle", isSelected: selectedTab == .about) {
                        selectedTab = .about
                    }
                }
                .padding(.horizontal, 10)
                
                Spacer()
            }
            .frame(width: 220)
            .background(.thickMaterial)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedTab.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView()
                        case .menuBar:
                            MenuBarSettingsView()
                        case .panel:
                            PanelSettingsView()
                        case .about:
                            AboutSettingsView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
        }
        .frame(width: 650, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(Color.clear)
        .ignoresSafeArea()
    }
}

// MARK: - Subviews

struct GeneralSettingsView: View {
    @StateObject private var autoLaunchManager = AutoLaunchManager()
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var powerSaving = PowerSavingManager.shared
    @AppStorage("appLanguage") private var appLanguage = "auto"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Launch at Login Group
                SettingsGroup {
                    Toggle("Launch at Login".localized, isOn: Binding(
                        get: { autoLaunchManager.isEnabled },
                        set: { isEnabled in
                            autoLaunchManager.toggle(isEnabled)
                        }
                    ))
                    
                    Divider().padding(.vertical, 8)
                    
                    Text("This will start SystemMonitor automatically when you log in.".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Language Group
                SettingsGroup {
                    HStack {
                        Text("Language".localized)
                        Spacer()
                        Picker("", selection: $appLanguage) {
                            Text("Automatic".localized).tag("auto")
                            Text("繁體中文").tag("zh-Hant")
                            Text("English").tag("en")
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                
                // Power Saving Group
                SettingsGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Power Saving".localized)
                            .font(.headline)
                        
                        Divider()
                        
                        // Timer Intervals
                        VStack(spacing: 8) {
                            IntervalSlider(
                                title: "Network Update".localized,
                                value: $powerSaving.networkUpdateInterval,
                                range: 1.0...10.0
                            )
                            
                            IntervalSlider(
                                title: "System Info Update".localized,
                                value: $powerSaving.systemInfoUpdateInterval,
                                range: 1.0...10.0
                            )
                            
                            IntervalSlider(
                                title: "Temperature Update".localized,
                                value: $powerSaving.temperatureUpdateInterval,
                                range: 2.0...30.0
                            )
                        }
                        
                        Divider()
                        
                        // Toggles
                        Toggle("Pause When Panel Closed".localized, isOn: $powerSaving.pauseWhenPanelClosed)
                        Text("Stops non-essential monitoring when panel is hidden.".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Toggle("Use Efficient Timers".localized, isOn: $powerSaving.useEfficientTimers)
                        Text("Allows system to coalesce timers for better battery life.".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Interval Slider Helper
struct IntervalSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Slider(value: $value, in: range, step: 0.5)
                .frame(width: 120)
            Text("\(value, specifier: "%.1f")s")
                .frame(width: 40)
                .foregroundStyle(.secondary)
        }
    }
}

struct MenuBarSettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    
    // Display Preferences
    @AppStorage("showArrows") private var showArrows = false
    @AppStorage("arrowPosition") private var arrowPosition = "Right" // "Left", "Right"
    @AppStorage("unitStyle") private var unitStyle = "standard" // standard, suffix, lowercase_suffix, lowercase
    @AppStorage("textFormat") private var textFormat = "4 Digits" // "4 Digits", "3 Digits", "2 Digits + Decimal"
    @AppStorage("showUpload") private var showUpload = true
    @AppStorage("showDownload") private var showDownload = true
    
    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup {
                // Text Format
                HStack {
                    Text("Text Format".localized)
                    Spacer()
                    Picker("", selection: $textFormat) {
                        Text("4 Digits".localized).tag("4 Digits")
                        Text("3 Digits".localized).tag("3 Digits")
                        Text("2 Digits + Decimal".localized).tag("2 Digits + Decimal")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                
                Divider().padding(.vertical, 8)
                
                // Unit Style
                HStack {
                    Text("Unit Style".localized)
                    Spacer()
                    Picker("", selection: $unitStyle) {
                        Text("KB/MB").tag("standard")
                        Text("KB/s / MB/s").tag("suffix")
                        Text("kb/s / mb/s").tag("lowercase_suffix")
                        Text("kb / mb").tag("lowercase")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                
                Divider().padding(.vertical, 8)
                
                Toggle("Show Arrows".localized, isOn: $showArrows)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if showArrows {
                    Divider().padding(.vertical, 8)
                    
                    HStack {
                        Text("Arrow Position".localized)
                        Spacer()
                        Picker("", selection: $arrowPosition) {
                            Text("Right".localized).tag("Right")
                            Text("Left".localized).tag("Left")
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                Toggle("Show Upload".localized, isOn: $showUpload)
                Toggle("Show Download".localized, isOn: $showDownload)
            }
        }
    }
}

struct PanelSettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    
    @AppStorage("menuBarOpacity") private var menuBarOpacity: Double = 0.8
    @AppStorage("cardOpacity") private var cardOpacity: Double = 1.0
    @AppStorage("appDisplayCount") private var appDisplayCount: Int = 5
    @AppStorage("menuBarWidth") private var menuBarWidth: Double = 340.0
    @AppStorage("uploadColor") private var uploadColorHex = "#007AFF"
    @AppStorage("downloadColor") private var downloadColorHex = "#34C759"
    @AppStorage("appListStyle") private var appListStyle = "Icon + Name"

    var body: some View {
        VStack(spacing: 16) {
            SettingsGroup {
                // Panel Background Opacity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Panel Opacity".localized)
                        Spacer()
                        Text("\(Int(menuBarOpacity * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $menuBarOpacity, in: 0.1...1.0)
                        .tint(.blue)
                }
                
                Divider().padding(.vertical, 8)
                
                // Card Opacity
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Card Opacity".localized)
                        Spacer()
                        Text("\(Int(cardOpacity * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cardOpacity, in: 0.3...1.0)
                        .tint(.blue)
                }
                
                Divider().padding(.vertical, 8)
                
                // Width
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                         Text("Panel Width".localized)
                         Spacer()
                         Text("\(Int(menuBarWidth))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $menuBarWidth, in: 300...800, step: 10)
                }
                
                Divider().padding(.vertical, 8)
                
                // Count
                HStack {
                    Text("App Display Count".localized)
                    Spacer()
                    Picker("", selection: $appDisplayCount) {
                        Text("All".localized).tag(0)
                        Text("3 Items".localized).tag(3)
                        Text("5 Items".localized).tag(5)
                        Text("7 Items".localized).tag(7)
                        Text("10 Items".localized).tag(10)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                
                Divider().padding(.vertical, 8)
                
                // List Style
                HStack {
                    Text("App List Style".localized)
                    Spacer()
                    Picker("", selection: $appListStyle) {
                        Text("Icon + Name".localized).tag("Icon + Name")
                        Text("Icon Only".localized).tag("Icon Only")
                        Text("Name Only".localized).tag("Name Only")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                
                Divider().padding(.vertical, 8)
                
                // Colors
                Group {
                    ColorPicker("Upload Color".localized, selection: Binding(
                        get: { Color(hex: uploadColorHex) },
                        set: { uploadColorHex = $0.toHex() }
                    ))
                    
                    ColorPicker("Download Color".localized, selection: Binding(
                        get: { Color(hex: downloadColorHex) },
                        set: { downloadColorHex = $0.toHex() }
                    ))
                }
                
                Divider().padding(.vertical, 8)
                
                // Show Top Processes
                Toggle("Show Top Processes".localized, isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "showTopProcesses") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "showTopProcesses") }
                ))
            }
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        SettingsGroup {
            HStack {
                Text("Version".localized)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            
            Divider().padding(.vertical, 8)
            
            HStack {
                Text("Build".localized)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Components

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5)) // Lighter background for groups
        .cornerRadius(12)
    }
}
