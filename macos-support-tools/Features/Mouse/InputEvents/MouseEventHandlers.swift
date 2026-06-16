import Foundation
import CoreGraphics
import IOKit.hid

// MARK: - HID Manager Callbacks

func deviceAddedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        if let newDevice = manager.createMouseDevice(from: device) {
            manager.addDevice(newDevice)
        }
    }
}

func deviceRemovedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
    let manager = Unmanaged<MouseManager>.fromOpaque(context!).takeUnretainedValue()
    DispatchQueue.main.async {
        if let removedDevice = manager.createMouseDevice(from: device) {
            manager.removeDevice(removedDevice)
        }
    }
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

    applyScrollReversalIfNeeded(to: event, manager: manager)
    
    return Unmanaged.passRetained(event)
}

@discardableResult
func applyScrollReversalIfNeeded(to event: CGEvent, manager: MouseManager) -> Bool {
    guard manager.shouldReverseScroll() else {
        return false
    }

    let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
    let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)

    guard scrollPhase == 0, momentumPhase == 0 else {
        return false
    }

    let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
    let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
    let pointDeltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
    let pointDeltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
    let fixedPointDeltaY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
    let fixedPointDeltaX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)

    guard deltaY != 0
        || deltaX != 0
        || pointDeltaY != 0
        || pointDeltaX != 0
        || fixedPointDeltaY != 0
        || fixedPointDeltaX != 0 else {
        return false
    }

    event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: deltaY * -1)
    event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: deltaX * -1)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointDeltaY * -1)
    event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointDeltaX * -1)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixedPointDeltaY * -1)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixedPointDeltaX * -1)

    return true
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
    
    if manager.citrixPassthroughEnabled && manager.citrixMonitor.isCitrixActive {
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

// MARK: - Keyboard Event Tap Callback

func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }
    
    let manager = Unmanaged<MouseManager>.fromOpaque(refcon).takeUnretainedValue()
    
    if manager.keyboardBlocked {
        // Block the keyboard event by returning nil
        return nil
    }
    
    return Unmanaged.passRetained(event)
}
