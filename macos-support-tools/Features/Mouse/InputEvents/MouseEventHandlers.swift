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

// These run on `EventTapThread`, never the main thread, so they must not touch
// the observable managers; everything they need comes from the controller's
// lock-protected `settings` snapshot.

nonisolated func scrollEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<MouseEventTapController>.fromOpaque(refcon).takeUnretainedValue()

    if type.isTapDisabledEvent {
        controller.handleScrollTapDisabled(type)
        return Unmanaged.passUnretained(event)
    }

    // Only apply scroll reversal if we have an external mouse connected and
    // natural scrolling is disabled in the published settings snapshot.
    if controller.settings.shouldReverseScroll {
        reverseScrollIfNeeded(event)
    }

    return Unmanaged.passUnretained(event)
}

nonisolated func reverseScrollIfNeeded(_ event: CGEvent) {
    guard let reversal = ScrollReversalPolicy.reversal(for: event.scrollEventDescriptor) else {
        return
    }

    event.applyScrollReversal(reversal)
}

extension CGEvent {
    nonisolated var scrollEventDescriptor: ScrollEventDescriptor {
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

    nonisolated func applyScrollReversal(_ reversal: ScrollReversal) {
        setDoubleValueField(.scrollWheelEventDeltaAxis1, value: reversal.deltas.vertical)
        setDoubleValueField(.scrollWheelEventDeltaAxis2, value: reversal.deltas.horizontal)

        guard let pointDeltas = reversal.pointDeltas else {
            return
        }

        setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: pointDeltas.vertical)
        setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: pointDeltas.horizontal)
    }
}

nonisolated func buttonEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<MouseEventTapController>.fromOpaque(refcon).takeUnretainedValue()

    if type.isTapDisabledEvent {
        controller.handleButtonTapDisabled(type)
        return Unmanaged.passUnretained(event)
    }

    // Buttons the user has not claimed, and every button while Citrix passthrough
    // applies, arrive here with no action to run.
    let settings = controller.settings

    // Check if the event is from a side button (Button 4 or Button 5)
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)

    switch buttonNumber {
    case 4:
        // Button 4 (Forward) - check if we should override the action
        if let action = settings.button4Action {
            return handleButtonAction(event: event, action: action)
        }
    case 3:
        // Button 5 (Back) - check if we should override the action
        if let action = settings.button5Action {
            return handleButtonAction(event: event, action: action)
        }
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - Button Action Handler

nonisolated private func handleButtonAction(event: CGEvent, action: MouseButtonAction) -> Unmanaged<CGEvent>? {
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
nonisolated private func simulateKeyboardShortcut(keyCode: CGKeyCode, modifiers: CGEventFlags) {
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
