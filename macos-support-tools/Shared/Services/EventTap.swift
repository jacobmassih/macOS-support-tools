import CoreGraphics
import Foundation

final class EventTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?

    var isInstalled: Bool {
        machPort != nil
    }

    @discardableResult
    func install(
        eventMask: CGEventMask,
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?
    ) -> Bool {
        guard machPort == nil else { return true }

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
            CFMachPortInvalidate(machPort)
            return false
        }

        let runLoop = CFRunLoopGetCurrent()

        self.machPort = machPort
        self.runLoopSource = runLoopSource
        self.runLoop = runLoop

        CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: machPort, enable: true)
        return true
    }

    func reenable() {
        guard let machPort else { return }

        CGEvent.tapEnable(tap: machPort, enable: true)
    }

    func uninstall() {
        if let machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
            self.machPort = nil
        }

        if let runLoopSource, let runLoop {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
        }

        runLoopSource = nil
        runLoop = nil
    }
}
