//
//  CitrixMonitor.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-10-26.
//

import Foundation
import AppKit

@Observable class CitrixMonitor {
    private var _isCitrixActive: Bool = false
    private let lock = NSLock()
    private var observer: NSObjectProtocol?
    
    var isCitrixActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCitrixActive
    }
    
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
        let newState = checkIfCitrixIsActive()
        lock.lock()
        _isCitrixActive = newState
        lock.unlock()
    }
    
    private func checkIfCitrixIsActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return false
        }
        
        return bundleId == "com.citrix.receiver.icaviewer.mac"
    }
}
