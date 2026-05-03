//
//  MouseManager.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Foundation
import IOKit
import IOKit.hid
import CoreGraphics
import AppKit

@Observable class MouseManager {
    var connectedDevices: [MouseDevice] = []
    var deviceSettings: [String: MouseDevice] = [:]
    var isAnyExternalMouseConnected = false
    var aggressiveInversion = false
    var tapStatus = "Inactive"
    var mouseButtonsEnabled = true {
        didSet {
            UserDefaults.standard.set(mouseButtonsEnabled, forKey: "MouseButtonsEnabled")
        }
    }
    var naturalScrollEnabled = true {
        didSet {
            UserDefaults.standard.set(naturalScrollEnabled, forKey: "NaturalScrollEnabled")
        }
    }
    var keyboardBlocked = false {
        didSet {
            if keyboardBlocked {
                setupKeyboardEventTap()
            } else {
                disableKeyboardEventTap()
            }
        }
    }
    
    let citrixMonitor = CitrixMonitor()
    
    private var hidManager: IOHIDManager?
    private var eventTap: CFMachPort?
    private var buttonEventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buttonRunLoopSource: CFRunLoopSource?
    private var keyboardEventTap: CFMachPort?
    private var keyboardRunLoopSource: CFRunLoopSource?
    private let userDefaults = UserDefaults.standard
    private let deviceSettingsKey = "MouseDeviceSettings"
    private var deviceMonitorTimer: Timer?
    private var lastEventTime: CFTimeInterval = 0
    
    init() {
                                                print("[MouseManager] Initialized and starting up.")
        setupHIDManager()
        detectInitialDevices()
        setupScrollEventTap()
        setupButtonEventTap()
        updateTapStatus()
        loadDeviceSettings()
        startDeviceMonitor()
        
        naturalScrollEnabled = UserDefaults.standard.bool(forKey: "NaturalScrollEnabled")
        mouseButtonsEnabled = UserDefaults.standard.bool(forKey: "MouseButtonsEnabled")
    }
    
    deinit {
        disableScrollEventTap()
        disableButtonEventTap()
        disableKeyboardEventTap()
        stopDeviceMonitor()
    }
    
    // MARK: - Public Methods
    
    func toggleScrollDirection() {
        naturalScrollEnabled.toggle()
    }
    
    func toggleMouseButtons() {
        mouseButtonsEnabled.toggle()
    }
    
    func updateButtonSettings(for deviceId: String, buttonType: MouseButtonType, enabled: Bool) {
        guard var device = deviceSettings[deviceId] else { return }
        
        switch buttonType {
        case .left:
            device.leftButtonEnabled = enabled
        case .right:
            device.rightButtonEnabled = enabled
        case .middle:
            device.middleButtonEnabled = enabled
        case .button4:
            device.button4Enabled = enabled
        case .button5:
            device.button5Enabled = enabled
        }
        
        deviceSettings[deviceId] = device
        saveDeviceSettings()
    }
    
    func updateButtonAction(for deviceId: String, buttonType: MouseButtonType, action: MouseButtonAction) {
        guard var device = deviceSettings[deviceId] else { return }
        
        switch buttonType {
        case .button4:
            device.button4Action = action
        case .button5:
            device.button5Action = action
        default:
            break // Only side buttons support action configuration
        }
        
        deviceSettings[deviceId] = device
        saveDeviceSettings()
    }
    
    // MARK: - Internal Methods (accessible by callbacks)
    
    internal func createMouseDevice(from ioDevice: IOHIDDevice) -> MouseDevice? {
        let _ = ioDevice.deviceID // Suppress warning, deviceID is used for debugging purposes
        let vendorID = ioDevice.vendorID
        let productID = ioDevice.productID
        let deviceName = ioDevice.productString ?? "Unknown Device"
        
        let id = "\(vendorID)-\(productID)"
        
        return MouseDevice(
            id: id,
            name: deviceName,
            vendorID: vendorID,
            productID: productID,
            naturalScrollEnabled: true,
            lastConnected: Date(),
            leftButtonEnabled: true,
            rightButtonEnabled: true,
            middleButtonEnabled: true,
            button4Enabled: true,
            button5Enabled: true,
            button4Action: .forward,
            button5Action: .back
        )
    }
    
    internal func addDevice(_ device: MouseDevice) {
        connectedDevices.append(device)
        deviceSettings[device.id] = device
        saveDeviceSettings()
    }
    
    internal func removeDevice(_ device: MouseDevice) {
        connectedDevices.removeAll { $0.id == device.id }
        deviceSettings.removeValue(forKey: device.id)
        saveDeviceSettings()
    }
    
    internal func getCurrentActiveDevice() -> MouseDevice? {
        // For now, just return the first connected device as the active device
        return connectedDevices.first
    }
    
    internal func shouldReverseScroll() -> Bool {
        return isAnyExternalMouseConnected && !naturalScrollEnabled
    }
    
    // MARK: - Private Methods
    
    private func updateTapStatus() {
        if eventTap != nil {
            tapStatus = "Active"
        } else {
            tapStatus = "Inactive - Accessibility permission required"
        }
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
            // Check if any external mouse is connected
            isAnyExternalMouseConnected = CFSetGetCount(devices) > 0
            
            // Convert CFSet to Array safely
            let deviceCount = CFSetGetCount(devices)
            if deviceCount > 0 {
                let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: deviceCount)
                defer { values.deallocate() }
                CFSetGetValues(devices, values)
                
                let deviceArray = (0..<deviceCount).compactMap { index -> IOHIDDevice? in
                    guard let devicePointer = values[index] else { return nil }
                    // The device pointer is already an IOHIDDevice, no need to dereference with .pointee
                    return Unmanaged<IOHIDDevice>.fromOpaque(devicePointer).takeUnretainedValue()
                }
                
                // Update connected devices list
                connectedDevices = deviceArray.compactMap { device in
                    return createMouseDevice(from: device)
                }
            }
        }
    }
    
    private func setupScrollEventTap() {
        let eventMask = (1 << CGEventType.scrollWheel.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: scrollEventCallback,
            userInfo: context
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap. App may need accessibility permissions.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else { return }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func disableScrollEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }
    
    private func setupButtonEventTap() {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        buttonEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: buttonEventCallback,
            userInfo: context
        )
        
        guard let buttonEventTap = buttonEventTap else {
            print("Failed to create button event tap. App may need accessibility permissions.")
            return
        }
        
        buttonRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, buttonEventTap, 0)
        guard let buttonRunLoopSource = buttonRunLoopSource else { return }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), buttonRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: buttonEventTap, enable: true)
    }
    
    private func disableButtonEventTap() {
        if let buttonEventTap = buttonEventTap {
            CGEvent.tapEnable(tap: buttonEventTap, enable: false)
            CFMachPortInvalidate(buttonEventTap)
            self.buttonEventTap = nil
        }
        
        if let buttonRunLoopSource = buttonRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), buttonRunLoopSource, .commonModes)
            self.buttonRunLoopSource = nil
        }
    }
    
    private func setupKeyboardEventTap() {
        guard keyboardEventTap == nil else { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        keyboardEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keyboardEventCallback,
            userInfo: context
        )
        
        guard let keyboardEventTap = keyboardEventTap else {
            print("Failed to create keyboard event tap. App may need accessibility permissions.")
            return
        }
        
        keyboardRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyboardEventTap, 0)
        guard let keyboardRunLoopSource = keyboardRunLoopSource else { return }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
    }
    
    private func disableKeyboardEventTap() {
        if let keyboardEventTap = keyboardEventTap {
            CGEvent.tapEnable(tap: keyboardEventTap, enable: false)
            CFMachPortInvalidate(keyboardEventTap)
            self.keyboardEventTap = nil
        }
        
        if let keyboardRunLoopSource = keyboardRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
            self.keyboardRunLoopSource = nil
        }
    }
    
    private func startDeviceMonitor() {
        deviceMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkDeviceConnectionStatus()
        }
    }
    
    private func stopDeviceMonitor() {
        deviceMonitorTimer?.invalidate()
        deviceMonitorTimer = nil
    }
    
    private func checkDeviceConnectionStatus() {
        guard let hidManager = hidManager else { return }
        
        let deviceSet = IOHIDManagerCopyDevices(hidManager)
        if let devices = deviceSet {
            // Convert CFSet to Array safely and get device IDs
            let deviceCount = CFSetGetCount(devices)
            var currentDeviceIDs: [String] = []
            
            if deviceCount > 0 {
                let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: deviceCount)
                defer { values.deallocate() }
                CFSetGetValues(devices, values)
                
                currentDeviceIDs = (0..<deviceCount).compactMap { index -> String? in
                    guard let devicePointer = values[index] else { return nil }
                    // Use the same safe pattern as detectInitialDevices
                    let device = Unmanaged<IOHIDDevice>.fromOpaque(devicePointer).takeUnretainedValue()
                    return device.deviceID
                }
            }
            
            // Update connection status for each device
            for device in connectedDevices {
                if !currentDeviceIDs.contains(device.id) {
                    // Device is disconnected
                    removeDevice(device)
                }
            }
            
            // Check if any external mouse is connected
            isAnyExternalMouseConnected = deviceCount > 0
        }
    }
    
    private func updateCurrentActiveDevice(naturalScroll: Bool) {
        guard let activeDevice = getCurrentActiveDevice() else { return }
        
        // Update the natural scroll setting for the active device
        var updatedDevice = activeDevice
        updatedDevice.naturalScrollEnabled = naturalScroll
        
        // Save the updated device settings
        deviceSettings[activeDevice.id] = updatedDevice
        saveDeviceSettings()
    }
    
    // MARK: - Device Settings Persistence
    
    private func loadDeviceSettings() {
        guard let data = userDefaults.data(forKey: deviceSettingsKey),
              let savedSettings = try? JSONDecoder().decode([String: MouseDevice].self, from: data) else {
            return
        }
        
        deviceSettings = savedSettings
        
        // Update connected devices with saved settings
        for (index, device) in connectedDevices.enumerated() {
            if let savedDevice = deviceSettings[device.id] {
                connectedDevices[index] = savedDevice
            }
        }
    }
    
    private func saveDeviceSettings() {
        guard let data = try? JSONEncoder().encode(deviceSettings) else {
            print("Failed to encode device settings")
            return
        }
        
        userDefaults.set(data, forKey: deviceSettingsKey)
    }
}
