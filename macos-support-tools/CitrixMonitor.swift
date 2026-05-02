//
//  CitrixMonitor.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-10-26.
//

import Foundation
import AppKit

@Observable class CitrixMonitor {
    @ObservationIgnored private let stateLock = NSLock()
    @ObservationIgnored private var _isCitrixActive: Bool = false
    @ObservationIgnored var onStateChange: ((Bool) -> Void)?
    private var observer: NSObjectProtocol?

    var isCitrixActive: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isCitrixActive
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard observer == nil else { return }

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
        setCitrixActive(checkIfCitrixIsActive())
    }

    private func setCitrixActive(_ isActive: Bool) {
        stateLock.lock()
        _isCitrixActive = isActive
        stateLock.unlock()

        onStateChange?(isActive)
    }
    
    private func checkIfCitrixIsActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return false
        }
        
        // Citrix Viewer is the remote session process launched by Citrix Workspace.
        return bundleId == "com.citrix.receiver.icaviewer.mac"
    }
}
