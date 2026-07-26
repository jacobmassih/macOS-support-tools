import CoreGraphics
import Foundation
import os

final class EventTap {
    private static let logger = Logger(
        subsystem: "com.mst.macos-support-tools",
        category: "EventTap"
    )

    private let label: String
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?

    private(set) var installedEventMask: CGEventMask?

    var isInstalled: Bool {
        machPort != nil
    }

    /// - Parameter label: Human-readable tap name used in log messages.
    init(label: String) {
        self.label = label
    }

    deinit {
        uninstall()
    }

    /// Installs the tap on the current run loop. `target` is passed unretained to the
    /// callback as `refcon`, so it must outlive the tap. Installing over an existing
    /// tap is a no-op when the mask matches and reinstalls the tap when it differs.
    @discardableResult
    func install(
        eventMask: CGEventMask,
        callback: CGEventTapCallBack,
        target: AnyObject
    ) -> Bool {
        if machPort != nil {
            guard installedEventMask != eventMask else { return true }
            uninstall()
        }

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(target).toOpaque())
        ) else {
            Self.logger.error(
                "Failed to create \(self.label, privacy: .public) event tap. App may need accessibility permissions."
            )
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
            CFMachPortInvalidate(machPort)
            Self.logger.error(
                "Failed to create run loop source for \(self.label, privacy: .public) event tap."
            )
            return false
        }

        let runLoop = CFRunLoopGetCurrent()

        self.machPort = machPort
        self.runLoopSource = runLoopSource
        self.runLoop = runLoop
        installedEventMask = eventMask

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
        installedEventMask = nil
    }
}
