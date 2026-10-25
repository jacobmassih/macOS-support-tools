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
        manager.removeDevice(withID: device.deviceID)
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
        return Unmanaged.passUnretained(event)
    }
    
    let manager = Unmanaged<MouseManager>.fromOpaque(refcon).takeUnretainedValue()

    if type.isTapDisabledEvent {
        print("[MouseManager] Scroll tap disabled by the system; re-enabling.")
        manager.reenableScrollEventTap()
        return Unmanaged.passUnretained(event)
    }

    // Only apply scroll reversal if we have external mouse connected and conditions are met
    if manager.shouldReverseScroll() {
        reverseScrollIfNeeded(event)
    }

    return Unmanaged.passUnretained(event)
}

func reverseScrollIfNeeded(_ event: CGEvent) {
    guard let reversal = ScrollReversalPolicy.reversal(for: event.scrollEventDescriptor) else {
        return
    }

    event.applyScrollReversal(reversal)
}

extension CGEvent {
    var scrollEventDescriptor: ScrollEventDescriptor {
        ScrollEventDescriptor(
            deltas: ScrollWheelDeltas(
                vertical: getDoubleValueField(.scrollWheelEventDeltaAxis1),
                horizontal: getDoubleValueField(.scrollWheelEventDeltaAxis2)
            ),
            pointDeltas: ScrollWheelDeltas(
                vertical: getDoubleValueField(.scrollWheelEventPointDeltaAxis1),
                horizontal: getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
            ),
            scrollPhase: getIntegerValueField(.scrollWheelEventScrollPhase),
            momentumPhase: getIntegerValueField(.scrollWheelEventMomentumPhase)
        )
    }

    func applyScrollReversal(_ reversal: ScrollReversal) {
        setDoubleValueField(.scrollWheelEventDeltaAxis1, value: reversal.deltas.vertical)
        setDoubleValueField(.scrollWheelEventDeltaAxis2, value: reversal.deltas.horizontal)

        guard let pointDeltas = reversal.pointDeltas else {
            return
        }

        setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointDeltas.vertical)
        setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointDeltas.horizontal)
    }
}

func buttonEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
        guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    
    let manager = Unmanaged<MouseManager>.fromOpaque(refcon).takeUnretainedValue()

    if type.isTapDisabledEvent {
        print("[MouseManager] Button tap disabled by the system; re-enabling.")
        manager.reenableButtonEventTap()
        return Unmanaged.passUnretained(event)
    }

    if manager.mouseButtonsEnabled == false {
        return Unmanaged.passUnretained(event)
    }
    
    if manager.citrixPassthroughEnabled && manager.citrixMonitor.isCitrixActive {
        return Unmanaged.passUnretained(event)
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
    
    return Unmanaged.passUnretained(event)
}

// MARK: - Button Action Handler

private func handleButtonAction(event: CGEvent, action: MouseButtonAction) -> Unmanaged<CGEvent>? {
    // Only handle button down events to avoid duplicate actions
    let eventType = event.type
    if eventType != .otherMouseDown {
        return Unmanaged.passUnretained(event)
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
        
    case .none:
        break
    }
    
    return Unmanaged.passUnretained(event)
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
