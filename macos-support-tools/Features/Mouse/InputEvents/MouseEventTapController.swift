import Foundation
import CoreGraphics
import os

/// Owns the mouse event taps and keeps them installed only while a feature needs
/// them. An installed tap sits in the synchronous delivery path for every event
/// it masks, so an idle tap is not free: it makes this process a prerequisite for
/// scrolling and side-button clicks across the whole session.
///
/// This is the `refcon` the tap callbacks receive, so it is reachable from
/// `EventTapThread`. Only `settings` is shared with that thread, behind a lock;
/// the rest is main-thread state driven by `MouseManager`.
nonisolated final class MouseEventTapController: @unchecked Sendable {
    private static let scrollEventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    private static let buttonEventMask = CGEventMask(
        (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
    )

    private let scrollTap = EventTap(label: "scroll")
    private let buttonTap = EventTap(label: "mouse button")
    private let settingsLock = OSAllocatedUnfairLock(initialState: MouseTapSettings())
    private let notifyStatusChanged: @Sendable () -> Void

    // Main thread only.
    private var isScrollTapNeeded = false
    private var isButtonTapNeeded = false

    /// Read on the tap thread for every scroll and side-button event.
    var settings: MouseTapSettings {
        settingsLock.withLock { $0 }
    }

    /// True when every tap the enabled features require is installed. A tap no
    /// feature needs is deliberately absent, so its absence is not a fault.
    var hasRequiredMouseEventTaps: Bool {
        (!isScrollTapNeeded || scrollTap.status.isInstalled)
            && (!isButtonTapNeeded || buttonTap.status.isInstalled)
    }

    var needsAnyMouseEventTap: Bool {
        isScrollTapNeeded || isButtonTapNeeded
    }

    var isDisabledByRepeatedTimeouts: Bool {
        (isScrollTapNeeded && scrollTap.status.isDisabledByRepeatedTimeouts)
            || (isButtonTapNeeded && buttonTap.status.isDisabledByRepeatedTimeouts)
    }

    /// - Parameter onStatusChanged: Invoked on the main queue when a tap changed
    ///   state on its own, so the UI can catch up.
    init(onStatusChanged: @escaping @Sendable () -> Void) {
        self.notifyStatusChanged = onStatusChanged
    }

    func updateSettings(_ settings: MouseTapSettings) {
        settingsLock.withLock { $0 = settings }
    }

    /// Installs or tears down each tap to match what the enabled features need.
    ///
    /// `isAccessibilityEnabled` gates installation separately from need, so a tap
    /// that is wanted but cannot be created still reports as needed and the status
    /// can name the missing permission instead of an unexplained failure.
    func updateTaps(
        scrollTapNeeded: Bool,
        buttonTapNeeded: Bool,
        isAccessibilityEnabled: Bool
    ) {
        isScrollTapNeeded = scrollTapNeeded
        isButtonTapNeeded = buttonTapNeeded

        update(
            scrollTap,
            isNeeded: scrollTapNeeded && isAccessibilityEnabled,
            eventMask: Self.scrollEventMask,
            callback: scrollEventCallback
        )
        update(
            buttonTap,
            isNeeded: buttonTapNeeded && isAccessibilityEnabled,
            eventMask: Self.buttonEventMask,
            callback: buttonEventCallback
        )
    }

    func handleScrollTapDisabled(_ type: CGEventType) {
        handleTapDisabled(scrollTap, type: type)
    }

    func handleButtonTapDisabled(_ type: CGEventType) {
        handleTapDisabled(buttonTap, type: type)
    }

    func disableAllTaps() {
        isScrollTapNeeded = false
        isButtonTapNeeded = false
        scrollTap.uninstall()
        buttonTap.uninstall()
    }

    private func handleTapDisabled(_ tap: EventTap, type: CGEventType) {
        guard type == .tapDisabledByTimeout else {
            // A user-initiated disable is not a stall, so it must not spend the
            // budget that exists to catch a callback which cannot keep up.
            tap.reenable()
            return
        }

        guard !tap.reenableAfterTimeout() else { return }

        notifyStatusChanged()
    }

    private func update(
        _ tap: EventTap,
        isNeeded: Bool,
        eventMask: CGEventMask,
        callback: CGEventTapCallBack
    ) {
        guard isNeeded else {
            tap.uninstall()
            return
        }

        tap.install(eventMask: eventMask, callback: callback, target: self)
    }
}
