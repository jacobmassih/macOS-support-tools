import Foundation
import AppKit

@Observable class CitrixMonitor {
    private(set) var isCitrixActive: Bool = false

    /// Called on the main thread when the active state changes. The mouse tap
    /// callbacks read a published snapshot rather than this object, so passthrough
    /// only follows the frontmost app if someone republishes on the change.
    @ObservationIgnored var onCitrixActiveChange: (() -> Void)?

    private var observer: NSObjectProtocol?

    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Initial check
        updateCitrixState()
        
        // Monitor app switches
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.updateCitrixState()
        }
    }
    
    func stopMonitoring() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
    
    private func updateCitrixState() {
        let isActive = checkIfCitrixIsActive()
        guard isActive != isCitrixActive else { return }

        isCitrixActive = isActive
        onCitrixActiveChange?()
    }
    
    private func checkIfCitrixIsActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return false
        }
        
        return bundleId == "com.citrix.receiver.icaviewer.mac"
    }
}
