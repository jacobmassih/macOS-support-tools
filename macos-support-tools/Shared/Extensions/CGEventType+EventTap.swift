import CoreGraphics

extension CGEventType {
    /// The system delivers these notification types to a tap callback regardless
    /// of its event mask, after disabling the tap; the callback must re-enable
    /// the tap or it stays dead for the rest of the process lifetime.
    ///
    /// Use this to recognise a notification, not to decide how to answer one. The
    /// two differ: `.tapDisabledByTimeout` means the callback stalled, while
    /// `.tapDisabledByUserInput` is user-initiated. Every caller branches on the
    /// specific type afterwards, because blindly re-arming a tap that suppresses
    /// every key would defeat the user's way out, and because only a stall should
    /// count against the timeout budget in `EventTapTimeoutBreaker`.
    nonisolated var isTapDisabledEvent: Bool {
        self == .tapDisabledByTimeout || self == .tapDisabledByUserInput
    }
}
