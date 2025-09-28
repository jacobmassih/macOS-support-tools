//
//  MouseManager.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Foundation
import IOKit
import IOKit.hid
import Combine

class MouseManager: ObservableObject {
    @Published var isExternalMouseConnected = false
    @Published var naturalScrollEnabled = true
    
    private var hidManager: IOHIDManager?
    
    init() {
        setupHIDManager()
        detectInitialDevices()
    }
    
    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let hidManager = hidManager else { return }
        
        let deviceMatching = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse
        ] as CFDictionary
        
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatching)
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, deviceAddedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hidManager, deviceRemovedCallback, context)
        
        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    private func detectInitialDevices() {
        guard let hidManager = hidManager else { return }
        
        let deviceSet = IOHIDManagerCopyDevices(hidManager)
        if let devices = deviceSet {
            let devicesArray = CFSetGetValues(devices, nil)
            // Check if any external mouse is connected
            isExternalMouseConnected = CFSetGetCount(devices) > 0
        }
    }
    
    func toggleScrollDirection() {
        let script = """
        defaults write NSGlobalDomain com.apple.swipescrolldirection -bool \(!naturalScrollEnabled)
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
            naturalScrollEnabled.toggle()
        } catch {
            print("Failed to change scroll direction: \(error)")
        }
    }
}

private func deviceAddedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isExternalMouseConnected = true
        manager.toggleScrollDirection()
    }
}

private func deviceRemovedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isExternalMouseConnected = false
        manager.toggleScrollDirection()
    }
}
