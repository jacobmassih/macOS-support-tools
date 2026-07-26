import CoreGraphics
import Foundation
import os

/// A CoreGraphics event tap installed on `EventTapThread`.
///
/// Every method runs its work on the tap thread, so the CoreFoundation state
/// below is only ever touched there and needs no locking. What the main thread
/// reads for the UI is mirrored into `status`, which does take a lock.
nonisolated final class EventTap: @unchecked Sendable {
    struct Status: Sendable {
        var isInstalled = false
        var isDisabledByRepeatedTimeouts = false
    }

    private static let logger = Logger(
        subsystem: "com.mst.macos-support-tools",
        category: "EventTap"
    )

    private static func monotonicSeconds() -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    private let label: String
    private let tapThread: EventTapThread
    private let statusLock = OSAllocatedUnfairLock(initialState: Status())

    // Tap thread only.
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var installedEventMask: CGEventMask?
    private var timeoutBreaker = EventTapTimeoutBreaker()

    /// Safe to read from any thread.
    var status: Status {
        statusLock.withLock { $0 }
    }

    /// - Parameters:
    ///   - label: Human-readable tap name used in log messages.
    ///   - tapThread: Run loop the tap is serviced on.
    init(label: String, tapThread: EventTapThread = .shared) {
        self.label = label
        self.tapThread = tapThread
    }

    deinit {
        uninstall()
    }

    /// Installs the tap. `target` is passed unretained to the callback as
    /// `refcon`, so it must outlive the tap; `uninstall()` waits for the tap
    /// thread, which is what makes that contract keepable. Installing over an
    /// existing tap reuses it when the mask matches and reinstalls when it differs.
    @discardableResult
    func install(
        eventMask: CGEventMask,
        callback: CGEventTapCallBack,
        target: AnyObject
    ) -> Bool {
        var didInstall = false

        tapThread.performAndWait {
            didInstall = installOnTapThread(
                eventMask: eventMask,
                callback: callback,
                target: target
            )
        }

        return didInstall
    }

    /// Re-arms a tap the system disabled. Use this only for disables that are not
    /// a stall; `reenableAfterTimeout()` is the path for timeouts.
    func reenable() {
        tapThread.performAndWait {
            guard let machPort else { return }

            CGEvent.tapEnable(tap: machPort, enable: true)
        }
    }

    /// Re-arms a tap the system disabled for timing out, unless repeated timeouts
    /// have tripped the breaker.
    ///
    /// - Returns: Whether the tap was re-armed. `false` means it was left disabled.
    @discardableResult
    func reenableAfterTimeout() -> Bool {
        var didReenable = false

        tapThread.performAndWait {
            didReenable = reenableAfterTimeoutOnTapThread()
        }

        return didReenable
    }

    func uninstall() {
        tapThread.performAndWait {
            uninstallOnTapThread()
        }
    }

    private func installOnTapThread(
        eventMask: CGEventMask,
        callback: CGEventTapCallBack,
        target: AnyObject
    ) -> Bool {
        if let existingPort = machPort {
            if installedEventMask == eventMask {
                // Reusing a live tap must not disturb it, but a tap the system or
                // the breaker left disabled keeps its port and mask, so reuse is
                // the moment to bring it back rather than hand back a dead tap.
                if !CGEvent.tapIsEnabled(tap: existingPort) {
                    timeoutBreaker.reset()
                    CGEvent.tapEnable(tap: existingPort, enable: true)
                    publishStatus()
                }
                return true
            }

            uninstallOnTapThread()
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

        self.machPort = machPort
        self.runLoopSource = runLoopSource
        installedEventMask = eventMask
        timeoutBreaker.reset()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: machPort, enable: true)
        publishStatus()
        return true
    }

    private func reenableAfterTimeoutOnTapThread() -> Bool {
        guard let machPort else { return false }

        let wasTripped = timeoutBreaker.isTripped

        guard timeoutBreaker.shouldReenable(at: Self.monotonicSeconds()) else {
            // Only the transition is worth an error; the breaker stays tripped
            // afterwards, so later timeouts must not restart the log spam.
            if !wasTripped, timeoutBreaker.isTripped {
                Self.logger.error(
                    """
                    Leaving \(self.label, privacy: .public) event tap disabled after \
                    \(EventTapTimeoutBreaker.budget, privacy: .public) timeouts within \
                    \(EventTapTimeoutBreaker.windowSeconds, privacy: .public)s. Its callback \
                    is not keeping up, and re-arming it would keep stalling input.
                    """
                )
                publishStatus()
            }
            return false
        }

        Self.logger.notice(
            """
            Re-enabling \(self.label, privacy: .public) event tap after a system timeout \
            (\(self.timeoutBreaker.timeoutsInWindow, privacy: .public) of \
            \(EventTapTimeoutBreaker.budget, privacy: .public) allowed in the current window).
            """
        )
        CGEvent.tapEnable(tap: machPort, enable: true)
        return true
    }

    private func uninstallOnTapThread() {
        if let machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
            self.machPort = nil
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        installedEventMask = nil
        timeoutBreaker.reset()
        publishStatus()
    }

    private func publishStatus() {
        let status = Status(
            isInstalled: machPort != nil,
            isDisabledByRepeatedTimeouts: timeoutBreaker.isTripped
        )

        statusLock.withLock { $0 = status }
    }
}
