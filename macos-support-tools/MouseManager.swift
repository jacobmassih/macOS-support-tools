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
import CoreGraphics

class MouseManager: ObservableObject {
    @Published var isExternalMouseConnected = false
    @Published var naturalScrollEnabled = true
    @Published var aggressiveInversion = false
    @Published var tapStatus = "Inactive"
    
    private var hidManager: IOHIDManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var connectedMouseDevices: Set<IOHIDDevice> = []
    private var lastMouseEventTime: CFTimeInterval = 0
    
    init() {
        setupHIDManager()
        detectInitialDevices()
        setupScrollEventTap()
        updateTapStatus()
    }
    
    deinit {
        disableScrollEventTap()
    }
    
    func toggleScrollDirection() {
        naturalScrollEnabled.toggle()
    }
    
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
            isExternalMouseConnected = CFSetGetCount(devices) > 0
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
    
    fileprivate func shouldReverseScroll() -> Bool {
        return isExternalMouseConnected && !naturalScrollEnabled
    }
}

private func deviceAddedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isExternalMouseConnected = true
    }
}

private func deviceRemovedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isExternalMouseConnected = false
    }
}

private func scrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    
    let manager = Unmanaged<MouseManager>.fromOpaque(refcon).takeUnretainedValue()
    
    // Only apply scroll reversal if we have external mouse connected and conditions are met
    if manager.shouldReverseScroll() {
        // Get the scroll deltas
        let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        
        // Check for momentum scrolling phases - trackpad specific
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        
        // If this has momentum phases, it's from trackpad - skip it completely
        if scrollPhase != 0 || momentumPhase != 0 {
            return Unmanaged.passRetained(event)
        }
        
        // Check if this looks like discrete wheel scrolling (mouse)
        // Mouse wheels typically generate integer or near-integer values
        let isDiscreteScrolling = (abs(deltaY - round(deltaY)) < 0.01) || (abs(deltaX - round(deltaX)) < 0.01)
        
        // Only apply reversal to discrete scrolling events (mouse wheels)
        if isDiscreteScrolling && (abs(deltaY) >= 1.0 || abs(deltaX) >= 1.0) {
            // This appears to be a mouse wheel event - apply reversal
            event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: deltaY * -1)
            event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: deltaX * -1)
            
            // Also reverse point deltas if they exist
            let pointDeltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            let pointDeltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
            if pointDeltaY != 0 || pointDeltaX != 0 {
                event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointDeltaY * -1)
                event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointDeltaX * -1)
            }
        }
    }
    
    return Unmanaged.passRetained(event)
}
