//
//  StatusBarManager.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Cocoa

class StatusBarManager {
    private var statusItem: NSStatusItem?
    var mouseManager: MouseManager?
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse Tools")
        }
        
        let menu = NSMenu()
        
        // Device info section
        let deviceMenuItem = NSMenuItem(title: "Connected Devices", action: nil, keyEquivalent: "")
        deviceMenuItem.isEnabled = false
        menu.addItem(deviceMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Action items
        menu.addItem(NSMenuItem(title: "Refresh Devices", action: #selector(refreshDevices), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    func updateStatus() {}
    
    @objc private func refreshDevices() {
        // Implement device refresh logic
    }
    
    
    @objc private func showPreferences() {
        // Implement preferences window
    }
    
    func updateDeviceList(_ devices: [IOHIDDevice]) {
        guard let menu = statusItem?.menu else { return }
        
        // Remove old device items (keep first 3 items: title, separator, and one action)
        while menu.numberOfItems > 3 {
            menu.removeItem(at: 2)
        }
        
        // Add device items
        for device in devices {
            let title = device.productString ?? "Unknown Device (\(device.deviceID))"
            let deviceItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            deviceItem.isEnabled = false
            menu.insertItem(deviceItem, at: 2)
        }
    }
}
