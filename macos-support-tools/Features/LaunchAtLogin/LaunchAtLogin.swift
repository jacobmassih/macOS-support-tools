import Foundation
import ServiceManagement
import Observation

@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool = false
    
    init() { refresh() }
    
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login status:", error)
        }
        
        refresh()
    }
}
