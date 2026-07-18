import Foundation
import CoreGraphics

final class MouseEventTapController {
    private weak var manager: MouseManager?
    private let scrollTap = EventTap()
    private let buttonTap = EventTap()

    var hasRequiredMouseEventTaps: Bool {
        scrollTap.isInstalled && buttonTap.isInstalled
    }

    init(manager: MouseManager) {
        self.manager = manager
    }

    func setupScrollEventTap() {
        install(
            scrollTap,
            eventMask: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
            callback: scrollEventCallback,
            failureMessage: "Failed to create event tap. App may need accessibility permissions."
        )
    }

    func reenableScrollEventTap() {
        scrollTap.reenable()
    }

    func disableScrollEventTap() {
        scrollTap.uninstall()
    }

    func setupButtonEventTap() {
        install(
            buttonTap,
            eventMask: CGEventMask(
                (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
            ),
            callback: buttonEventCallback,
            failureMessage: "Failed to create button event tap. App may need accessibility permissions."
        )
    }

    func reenableButtonEventTap() {
        buttonTap.reenable()
    }

    func disableButtonEventTap() {
        buttonTap.uninstall()
    }

    private func install(
        _ tap: EventTap,
        eventMask: CGEventMask,
        callback: CGEventTapCallBack,
        failureMessage: String
    ) {
        guard let manager, manager.isAccessibilityEnabled else {
            manager?.updateTapStatus()
            return
        }

        guard !tap.isInstalled else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(manager).toOpaque())

        guard tap.install(eventMask: eventMask, callback: callback, userInfo: context) else {
            print(failureMessage)
            return
        }

        manager.updateTapStatus()
    }
}
