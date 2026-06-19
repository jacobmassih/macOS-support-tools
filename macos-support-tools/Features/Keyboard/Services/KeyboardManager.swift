import CoreGraphics
import Foundation
import Observation

@Observable class KeyboardManager {
    @ObservationIgnored private var accessibilityTrusted = false
    @ObservationIgnored private let accessibilityTrustManager: AccessibilityTrustManager
    @ObservationIgnored private var accessibilityTrustObserverID: UUID?
    @ObservationIgnored private var keyboardEventTap: CFMachPort?
    @ObservationIgnored private var keyboardRunLoopSource: CFRunLoopSource?

    var keyboardBlocked = false {
        didSet {
            updateKeyboardEventTap()
        }
    }

    init(accessibilityTrustManager: AccessibilityTrustManager) {
        self.accessibilityTrustManager = accessibilityTrustManager
        accessibilityTrustObserverID = accessibilityTrustManager.addTrustChangeHandler { [weak self] accessibilityTrusted in
            self?.handleAccessibilityTrustDidChange(accessibilityTrusted)
        }
    }

    deinit {
        if let accessibilityTrustObserverID {
            accessibilityTrustManager.removeTrustChangeHandler(accessibilityTrustObserverID)
        }
        disableKeyboardEventTap()
    }

    private func handleAccessibilityTrustDidChange(_ accessibilityTrusted: Bool) {
        self.accessibilityTrusted = accessibilityTrusted
        updateKeyboardEventTap()
    }

    private func updateKeyboardEventTap() {
        if keyboardBlocked && accessibilityTrusted {
            setupKeyboardEventTap()
        } else {
            disableKeyboardEventTap()
        }
    }

    private func setupKeyboardEventTap() {
        guard keyboardEventTap == nil else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        keyboardEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keyboardEventCallback,
            userInfo: context
        )

        guard let keyboardEventTap else {
            print("Failed to create keyboard event tap. App may need accessibility permissions.")
            return
        }

        keyboardRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyboardEventTap, 0)
        guard let keyboardRunLoopSource else { return }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
    }

    private func disableKeyboardEventTap() {
        if let keyboardEventTap {
            CGEvent.tapEnable(tap: keyboardEventTap, enable: false)
            CFMachPortInvalidate(keyboardEventTap)
            self.keyboardEventTap = nil
        }

        if let keyboardRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
            self.keyboardRunLoopSource = nil
        }
    }
}

func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passRetained(event)
    }

    let keyboardManager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()

    if keyboardManager.keyboardBlocked {
        return nil
    }

    return Unmanaged.passRetained(event)
}
