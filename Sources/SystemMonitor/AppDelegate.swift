import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    
    var networkMonitor = NetworkMonitor()
    var processMonitor = ProcessMonitor()
    var systemInfo = SystemInfoMonitor()
    var temperatureMonitor = TemperatureMonitor()
    
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 400) // Default, but view will override
        
        let contentView = MenuBarView(
            networkMonitor: networkMonitor,
            processMonitor: processMonitor,
            systemInfo: systemInfo,
            temperatureMonitor: temperatureMonitor
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Setup button
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateButtonTitle()
        }
        
        // Subscribe to network updates
        networkMonitor.$uploadSpeed
            .combineLatest(networkMonitor.$downloadSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updateButtonTitle()
            }
            .store(in: &cancellables)
        
        // Observe UserDefaults changes for immediate UI update
        UserDefaults.standard.addObserver(self, forKeyPath: "showDecimals", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "unitStyle", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showArrows", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "arrowPosition", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "textFormat", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showUpload", options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: "showDownload", options: .new, context: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: Notification.Name("openSettings"),
            object: nil
        )
    }
    
    @objc func handleDefaultsChange() {
        updateButtonTitle()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as? UserDefaults === UserDefaults.standard {
            handleDefaultsChange()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    @objc func handleOpenSettings() {
        openSettings()
    }
    
    func updateButtonTitle() {
        guard let button = statusItem.button else { return }
        
        let showArrows = UserDefaults.standard.bool(forKey: "showArrows")
        let arrowPosition = UserDefaults.standard.string(forKey: "arrowPosition") ?? "Right"
        
        let showUpload = UserDefaults.standard.object(forKey: "showUpload") == nil ? true : UserDefaults.standard.bool(forKey: "showUpload")
        let showDownload = UserDefaults.standard.object(forKey: "showDownload") == nil ? true : UserDefaults.standard.bool(forKey: "showDownload")
        
        let upArrow = showArrows ? "↑" : ""
        let downArrow = showArrows ? "↓" : ""
        
        let upSpeed = formatSpeed(networkMonitor.uploadSpeed)
        let downSpeed = formatSpeed(networkMonitor.downloadSpeed)
        
        var lines: [String] = []
        
        if showUpload {
            if showArrows {
                if arrowPosition == "Right" {
                    lines.append("\(upSpeed)\(upArrow)")
                } else {
                    lines.append("\(upArrow)\(upSpeed)")
                }
            } else {
                 lines.append(upSpeed)
            }
        }
        
        if showDownload {
             if showArrows {
                if arrowPosition == "Right" {
                    lines.append("\(downSpeed)\(downArrow)")
                } else {
                    lines.append("\(downArrow)\(downSpeed)")
                }
            } else {
                 lines.append(downSpeed)
            }
        }
        
        // Create attributed string with two lines
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.lineSpacing = -4
        paragraphStyle.maximumLineHeight = 10
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        
        var fullText = lines.isEmpty ? "Monitor" : lines.joined(separator: "\n")
        
        let attributedString = NSMutableAttributedString(string: fullText, attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .baselineOffset: -4
        ])
        
        button.attributedTitle = attributedString
        
        // Resize button to fit content tightly
        button.sizeToFit()
    }
    
    func formatSpeed(_ bytes: Int64) -> String {
        return SpeedFormatter.format(bytes)
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate the app so the popover can receive input
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func openSettings() {
        // Close popover first
        popover.performClose(nil)
        
        // Show Dock icon
        NSApp.setActivationPolicy(.regular)
        
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.delegate = self
            window.center()
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // Hide Dock icon when settings closed
        NSApp.setActivationPolicy(.accessory)
        settingsWindow = nil
    }
}
