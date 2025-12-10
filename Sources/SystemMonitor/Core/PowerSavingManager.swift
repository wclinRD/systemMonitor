import Foundation

/// Manages power saving settings and provides centralized timer configuration
class PowerSavingManager: ObservableObject {
    nonisolated(unsafe) static let shared = PowerSavingManager()
    
    // MARK: - Published Settings
    @Published var networkUpdateInterval: Double {
        didSet { UserDefaults.standard.set(networkUpdateInterval, forKey: "networkUpdateInterval") }
    }
    @Published var systemInfoUpdateInterval: Double {
        didSet { UserDefaults.standard.set(systemInfoUpdateInterval, forKey: "systemInfoUpdateInterval") }
    }
    @Published var temperatureUpdateInterval: Double {
        didSet { UserDefaults.standard.set(temperatureUpdateInterval, forKey: "temperatureUpdateInterval") }
    }
    @Published var pauseWhenPanelClosed: Bool {
        didSet { UserDefaults.standard.set(pauseWhenPanelClosed, forKey: "pauseWhenPanelClosed") }
    }
    @Published var useEfficientTimers: Bool {
        didSet { UserDefaults.standard.set(useEfficientTimers, forKey: "useEfficientTimers") }
    }
    
    // Leeway for timer coalescing (500ms default)
    let timerLeeway: DispatchTimeInterval = .milliseconds(500)
    
    private init() {
        // Load from UserDefaults with defaults
        self.networkUpdateInterval = UserDefaults.standard.object(forKey: "networkUpdateInterval") as? Double ?? 1.0
        self.systemInfoUpdateInterval = UserDefaults.standard.object(forKey: "systemInfoUpdateInterval") as? Double ?? 2.0
        self.temperatureUpdateInterval = UserDefaults.standard.object(forKey: "temperatureUpdateInterval") as? Double ?? 5.0
        self.pauseWhenPanelClosed = UserDefaults.standard.object(forKey: "pauseWhenPanelClosed") as? Bool ?? true
        self.useEfficientTimers = UserDefaults.standard.object(forKey: "useEfficientTimers") as? Bool ?? true
    }
    
    /// Creates an efficient DispatchSourceTimer with leeway if enabled
    func createTimer(interval: Double, handler: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        
        if useEfficientTimers {
            timer.schedule(deadline: .now() + interval, repeating: interval, leeway: timerLeeway)
        } else {
            timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .nanoseconds(0))
        }
        
        timer.setEventHandler(handler: handler)
        return timer
    }
}
