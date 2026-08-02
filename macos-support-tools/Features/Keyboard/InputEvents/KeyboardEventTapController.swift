import CoreGraphics
import Foundation
import os

/// Everything the keyboard tap callback needs, flattened to plain values.
nonisolated struct KeyboardTapSettings: Equatable, Sendable {
    var isBlocked = false
    var isDebounceEnabled = false
    var debounceNanoseconds: UInt64 = 0

    var needsEventTap: Bool {
        isBlocked || isDebounceEnabled
    }
}

/// Owns the keyboard event tap and the state its callback reads.
///
/// This is the `refcon` the callback receives, so it is reachable from
/// `EventTapThread`. The settings and the debounce filter share one lock: the
/// filter is mutated on every keystroke from the tap thread and reset from the
/// main thread when settings change.
nonisolated final class KeyboardEventTapController: @unchecked Sendable {
    private struct State {
        var settings = KeyboardTapSettings()
        var debounceFilter = KeyboardDebounceFilter()
    }

    private static let logger = Logger(
        subsystem: "com.mst.macos-support-tools",
        category: "KeyboardEventTapController"
    )

    private let tap = EventTap(label: "keyboard")
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let notifyBlockReleasedByUser: @Sendable () -> Void

    var isInstalled: Bool {
        tap.status.isInstalled
    }

    var isDisabledByRepeatedTimeouts: Bool {
        tap.status.isDisabledByRepeatedTimeouts
    }

    /// - Parameter onBlockReleasedByUser: Invoked when the system disables the tap
    ///   at the user's request while the keyboard is blocked. That is the one way
    ///   out of a full block that does not depend on the mouse, so the owner has
    ///   to clear the flag rather than the tap silently re-arming.
    init(onBlockReleasedByUser: @escaping @Sendable () -> Void) {
        self.notifyBlockReleasedByUser = onBlockReleasedByUser
    }

    func updateSettings(_ settings: KeyboardTapSettings) {
        state.withLock { $0.settings = settings }
    }

    func resetDebounceFilter() {
        state.withLock { $0.debounceFilter.reset() }
    }

    func install(eventMask: CGEventMask) {
        tap.install(eventMask: eventMask, callback: keyboardEventCallback, target: self)
    }

    func uninstall() {
        tap.uninstall()
    }

    func shouldSuppressEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        // Read the event outside the lock: these are CoreGraphics calls, and the
        // lock is also taken from the main thread.
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let timestamp = event.timestamp
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        return state.withLock { state in
            if state.settings.isBlocked {
                return true
            }

            guard state.settings.isDebounceEnabled, type == .keyDown else {
                return false
            }

            return state.debounceFilter.shouldSuppressKeyDown(
                keyCode: keyCode,
                timestamp: timestamp,
                isAutorepeat: isAutorepeat,
                debounceNanoseconds: state.settings.debounceNanoseconds
            )
        }
    }

    func handleTapDisabled(_ type: CGEventType) {
        guard type == .tapDisabledByUserInput else {
            tap.reenableAfterTimeout()
            return
        }

        guard state.withLock({ $0.settings.isBlocked }) else {
            // Debounce is not a lockout, so there is no escape to honour here.
            Self.logger.notice("Keyboard tap disabled by user input; re-enabling for debounce.")
            tap.reenable()
            return
        }

        Self.logger.notice("Keyboard tap disabled by user input; releasing keyboard block.")
        notifyBlockReleasedByUser()
    }
}

nonisolated func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<KeyboardEventTapController>.fromOpaque(refcon).takeUnretainedValue()

    if type.isTapDisabledEvent {
        controller.handleTapDisabled(type)
        return Unmanaged.passUnretained(event)
    }

    if controller.shouldSuppressEvent(event, type: type) {
        return nil
    }

    return Unmanaged.passUnretained(event)
}
