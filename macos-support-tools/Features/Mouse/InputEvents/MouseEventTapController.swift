import Foundation
import CoreGraphics

final class MouseEventTapController {
    private weak var manager: MouseManager?
    private var eventTap: CFMachPort?
    private var buttonEventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buttonRunLoopSource: CFRunLoopSource?

    var hasRequiredMouseEventTaps: Bool {
        eventTap != nil && buttonEventTap != nil
    }

    init(manager: MouseManager) {
        self.manager = manager
    }

    func setupScrollEventTap() {
        guard let manager, manager.isAccessibilityEnabled else {
            manager?.updateTapStatus()
            return
        }

        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.scrollWheel.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(manager).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: scrollEventCallback,
            userInfo: context
        )

        guard let eventTap else {
            print("Failed to create event tap. App may need accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource else { return }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        manager.updateTapStatus()
    }

    func reenableScrollTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func disableScrollEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    func setupButtonEventTap() {
        guard let manager, manager.isAccessibilityEnabled else {
            manager?.updateTapStatus()
            return
        }

        guard buttonEventTap == nil else { return }

        let eventMask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(manager).toOpaque())

        buttonEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: buttonEventCallback,
            userInfo: context
        )

        guard let buttonEventTap else {
            print("Failed to create button event tap. App may need accessibility permissions.")
            return
        }

        buttonRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, buttonEventTap, 0)
        guard let buttonRunLoopSource else { return }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), buttonRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: buttonEventTap, enable: true)
        manager.updateTapStatus()
    }

    func reenableButtonTap() {
        guard let buttonEventTap else { return }
        CGEvent.tapEnable(tap: buttonEventTap, enable: true)
    }

    func disableButtonEventTap() {
        if let buttonEventTap {
            CGEvent.tapEnable(tap: buttonEventTap, enable: false)
            CFMachPortInvalidate(buttonEventTap)
            self.buttonEventTap = nil
        }

        if let buttonRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), buttonRunLoopSource, .commonModes)
            self.buttonRunLoopSource = nil
        }
    }
}
