import CoreGraphics

extension CGEventType {
    /// The system delivers these notification types to a tap callback regardless
    /// of its event mask, after disabling the tap; the callback must re-enable
    /// the tap or it stays dead for the rest of the process lifetime.
    var isTapDisabledEvent: Bool {
        self == .tapDisabledByTimeout || self == .tapDisabledByUserInput
    }
}
