import CoreGraphics

extension CGEventType {
    /// The system delivers these notification types to a tap callback regardless
    /// of its event mask, after disabling the tap; the callback must re-enable
    /// the tap or it stays dead for the rest of the process lifetime.
    ///
    /// Only use this where both types warrant the same response. The two differ:
    /// `.tapDisabledByTimeout` means the callback stalled, while
    /// `.tapDisabledByUserInput` is user-initiated. `keyboardEventCallback`
    /// deliberately branches on them separately, because blindly re-arming a tap
    /// that is suppressing every key would defeat the user's way out.
    var isTapDisabledEvent: Bool {
        self == .tapDisabledByTimeout || self == .tapDisabledByUserInput
    }
}
