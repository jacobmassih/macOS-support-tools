//
//  MouseEventHandlers.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Foundation
import CoreGraphics
import IOKit.hid
import AppKit

// MARK: - HID Manager Callbacks

func deviceAddedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isAnyExternalMouseConnected = true
        
        if let newDevice = manager.createMouseDevice(from: device) {
            manager.addDevice(newDevice)
        }
    }
}

func deviceRemovedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.isAnyExternalMouseConnected = false
        
        if let removedDevice = manager.createMouseDevice(from: device) {
            manager.removeDevice(removedDevice)
        }
    }
}

private func isCitrixWorkspaceActive() -> Bool {
    guard let activeApp = NSWorkspace.shared.frontmostApplication else {
        return false
    }
    
    let citrixBundleIds = [
        "com.citrix.receiver.icaviewer.mac",
        "com.citrix.XenAppViewer",
        "com.citrix.receiver.nomas"
    ]
    
    if let bundleId = activeApp.bundleIdentifier {
        return citrixBundleIds.contains(bundleId)
    }
    
    // Fallback: check by app name
    let appName = activeApp.localizedName ?? ""
    return appName.lowercased().contains("citrix workspace") ||
           appName.lowercased().contains("citrix receiver")
}

// MARK: - Event Tap Callbacks

func scrollEventCallback(
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

func buttonEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    
    let manager = Unmanaged<MouseManager>.fromOpaque(refcon).takeUnretainedValue()
    
    if manager.mouseButtonsEnabled == false {
        return Unmanaged.passRetained(event)
    }
    
    if isCitrixWorkspaceActive() {
        return Unmanaged.passRetained(event)
    }
    
    
    // Check if the event is from a side button (Button 4 or Button 5)
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
    
    switch buttonNumber {
    case 4:
        // Button 4 (Forward) - check if we should override the action
        if let device = manager.getCurrentActiveDevice(), device.button4Enabled {
            let action = device.button4Action
            return handleButtonAction(event: event, action: action)
        }
    case 3:
        // Button 5 (Back) - check if we should override the action
        if let device = manager.getCurrentActiveDevice(), device.button5Enabled {
            let action = device.button5Action
            return handleButtonAction(event: event, action: action)
        }
    default:
        break
    }
    
    return Unmanaged.passRetained(event)
}

// MARK: - Button Action Handler

private func handleButtonAction(event: CGEvent, action: MouseButtonAction) -> Unmanaged<CGEvent>? {
    // Only handle button down events to avoid duplicate actions
    let eventType = event.type
    if eventType != .otherMouseDown {
        return Unmanaged.passRetained(event)
    }
    
    switch action {
    case .back:
        simulateKeyboardShortcut(keyCode: 0x21, modifiers: .maskCommand) // Command + [
        return nil // Consume the event
        
    case .forward:
        simulateKeyboardShortcut(keyCode: 0x1E, modifiers: .maskCommand) // Command + ]
        return nil // Consume the event
        
    case .middleClick:
        // Simulate a middle click (button 3)
        let currentLocation = event.location
        let middleClickEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: currentLocation, mouseButton: .center)
        middleClickEvent?.post(tap: .cghidEventTap)
        
        let middleClickUpEvent = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: currentLocation, mouseButton: .center)
        middleClickUpEvent?.post(tap: .cghidEventTap)
        
        return nil // Event has been handled
        
    case .custom:
        // Handle custom action if needed
        break
    case .none:
        break
    }
    
    return Unmanaged.passRetained(event)
}

// MARK: - Utility Functions

// Simple and reliable keyboard shortcut simulation
private func simulateKeyboardShortcut(keyCode: CGKeyCode, modifiers: CGEventFlags) {
    guard let source = CGEventSource(stateID: .hidSystemState) else { return }
    
    // Create key down event
    if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
        keyDownEvent.flags = modifiers
        keyDownEvent.post(tap: .cghidEventTap)
    }
    
    // Create key up event
    if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
        keyUpEvent.flags = modifiers
        keyUpEvent.post(tap: .cghidEventTap)
    }
}

