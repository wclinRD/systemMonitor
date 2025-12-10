import Foundation
import ServiceManagement

@MainActor
class AutoLaunchManager: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        let service = SMAppService.mainApp
        self.isEnabled = (service.status == .enabled)
    }
    
    func toggle(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            // Update status immediately
            self.isEnabled = (service.status == .enabled)
        } catch {
            print("Failed to toggle auto-launch: \(error)")
            // Revert on failure
            DispatchQueue.main.async {
                self.checkStatus()
            }
        }
    }
}
