import Foundation
import CoreGraphics

protocol MouseEventTapControlling: AnyObject {
    var isScrollTapInstalled: Bool { get }
    var isButtonTapInstalled: Bool { get }
    func setupScrollEventTap()
    func setupButtonEventTap()
    func disableScrollEventTap()
    func disableButtonEventTap()
    func reenableScrollEventTap()
    func reenableButtonEventTap()
}

final class MouseEventTapController: MouseEventTapControlling {
    private weak var manager: MouseManager?
    private let scrollTap = EventTap(label: "scroll")
    private let buttonTap = EventTap(label: "mouse button")

    var isScrollTapInstalled: Bool { scrollTap.isInstalled }
    var isButtonTapInstalled: Bool { buttonTap.isInstalled }

    init(manager: MouseManager) {
        self.manager = manager
    }

    func setupScrollEventTap() {
        install(
            scrollTap,
            eventMask: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
            callback: scrollEventCallback
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
            callback: buttonEventCallback
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
        callback: CGEventTapCallBack
    ) {
        guard let manager, manager.isAccessibilityEnabled else {
            manager?.updateTapStatus()
            return
        }

        guard tap.install(eventMask: eventMask, callback: callback, target: manager) else { return }

        manager.updateTapStatus()
    }
}
