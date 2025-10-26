//
//  CitrixMonitor.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-10-26.
//

import Foundation
import AppKit

@Observable class CitrixMonitor {
    private(set) var isCitrixActive: Bool = false
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Initial check
        updateCitrixState()
        
        // Monitor app switches
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.updateCitrixState()
        }
    }
    
    private func updateCitrixState() {
        isCitrixActive = checkIfCitrixIsActive()
    }
    
    private func checkIfCitrixIsActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return false
        }
        
        return bundleId == "com.citrix.receiver.icaviewer.mac"
    }
}
