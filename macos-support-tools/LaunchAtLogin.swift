//
//  LaunchAtLogin.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-10-02.
//
import Foundation
import ServiceManagement
import Observation

@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool = false
    
    init() { refresh() }
    
    func refresh() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = false
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
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
