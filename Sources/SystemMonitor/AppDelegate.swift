import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var panelWindow: NSPanel?
    var settingsWindow: NSWindow?
    var eventMonitor: Any?  // For click-outside-to-close
    
    var networkMonitor = NetworkMonitor()
    var processMonitor = ProcessMonitor()
    var systemInfo = SystemInfoMonitor()
    var temperatureMonitor = TemperatureMonitor()
    
    var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create panel window (no triangle)
        let contentView = MenuBarView(
            networkMonitor: networkMonitor,
            processMonitor: processMonitor,
            systemInfo: systemInfo,
            temperatureMonitor: temperatureMonitor
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 550)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 550),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        
        // Round corners
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 16
        panel.contentView?.layer?.masksToBounds = true
        
        panelWindow = panel
        
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
        guard let panel = panelWindow, let button = statusItem.button else { return }
        
        if panel.isVisible {
            closePanel()
        } else {
            // Position panel below status bar button, centered
            guard let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) else { return }
            
            let panelWidth = panel.frame.width
            let panelHeight = panel.frame.height
            
            // Center the panel under the button
            let x = buttonFrame.midX - panelWidth / 2
            let y = buttonFrame.minY - panelHeight - 5 // 5pt gap below menu bar
            
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Start monitoring for clicks outside
            startEventMonitor()
        }
    }
    
    func closePanel() {
        panelWindow?.orderOut(nil)
        stopEventMonitor()
    }
    
    func startEventMonitor() {
        // Monitor both left and right mouse clicks
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // If click is outside the panel, close it
            if let panel = self?.panelWindow, panel.isVisible {
                self?.closePanel()
            }
        }
    }
    
    func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func openSettings() {
        // Close panel first
        closePanel()
        
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
