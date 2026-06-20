import CoreGraphics
import Foundation
import Observation

@Observable class KeyboardManager {
    enum DefaultsKey {
        static let keyboardChatterFilterEnabled = "KeyboardChatterFilterEnabled"
        static let keyboardChatterFilterDelayMilliseconds = "KeyboardChatterFilterDelayMilliseconds"
    }

    var keyboardChatterFilterEnabled = false {
        didSet {
            userDefaults.set(keyboardChatterFilterEnabled, forKey: DefaultsKey.keyboardChatterFilterEnabled)
            updateKeyboardEventTap()
            resetKeyboardChatterFilter()
        }
    }
    var keyboardChatterFilterDelayMilliseconds = 45.0 {
        didSet {
            let clampedDelayMilliseconds = keyboardChatterFilterDelayMilliseconds.clamped(to: 5...100)
            guard keyboardChatterFilterDelayMilliseconds == clampedDelayMilliseconds else {
                keyboardChatterFilterDelayMilliseconds = clampedDelayMilliseconds
                return
            }

            userDefaults.set(
                keyboardChatterFilterDelayMilliseconds,
                forKey: DefaultsKey.keyboardChatterFilterDelayMilliseconds
            )
            resetKeyboardChatterFilter()
        }
    }
    var keyboardBlocked = false {
        didSet {
            updateKeyboardEventTap()
        }
    }

    private let userDefaults: UserDefaults
    @ObservationIgnored private var isAccessibilityEnabled = false
    @ObservationIgnored private let accessibilityManager: AccessibilityManager
    @ObservationIgnored private var hasStartedSystemServices = false
    @ObservationIgnored private var accessibilityPermissionObserverID: UUID?
    @ObservationIgnored private var keyboardChatterFilter = KeyboardChatterFilter()
    @ObservationIgnored private var keyboardEventTap: CFMachPort?
    @ObservationIgnored private var keyboardRunLoopSource: CFRunLoopSource?

    init(
        userDefaults: UserDefaults = .standard,
        accessibilityManager: AccessibilityManager
    ) {
        self.userDefaults = userDefaults
        self.accessibilityManager = accessibilityManager
        accessibilityPermissionObserverID = accessibilityManager.observePermissionChanges { [weak self] isAccessibilityEnabled in
            self?.handleAccessibilityPermissionDidChange(isAccessibilityEnabled)
        }

        userDefaults.register(defaults: [
            DefaultsKey.keyboardChatterFilterEnabled: false,
            DefaultsKey.keyboardChatterFilterDelayMilliseconds: 45.0
        ])

        keyboardChatterFilterEnabled = userDefaults.bool(forKey: DefaultsKey.keyboardChatterFilterEnabled)
        keyboardChatterFilterDelayMilliseconds = userDefaults.double(
            forKey: DefaultsKey.keyboardChatterFilterDelayMilliseconds
        )
    }

    deinit {
        if let accessibilityPermissionObserverID {
            accessibilityManager.removePermissionChangeHandler(accessibilityPermissionObserverID)
        }
        disableKeyboardEventTap()
    }

    func startSystemServices() {
        guard !hasStartedSystemServices else { return }

        hasStartedSystemServices = true
        updateKeyboardEventTap()
    }

    private func handleAccessibilityPermissionDidChange(_ isAccessibilityEnabled: Bool) {
        self.isAccessibilityEnabled = isAccessibilityEnabled
        updateKeyboardEventTap()
    }

    private func updateKeyboardEventTap() {
        guard hasStartedSystemServices else { return }

        if (keyboardBlocked || keyboardChatterFilterEnabled) && isAccessibilityEnabled {
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

    internal func shouldSuppressKeyboardChatter(keyCode: Int64, timestamp: CGEventTimestamp) -> Bool {
        keyboardChatterFilter.shouldSuppressKeyDown(
            keyCode: keyCode,
            timestamp: timestamp,
            debounceNanoseconds: UInt64(keyboardChatterFilterDelayMilliseconds * 1_000_000)
        )
    }

    internal func resetKeyboardChatterFilter() {
        keyboardChatterFilter.reset()
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

    if shouldSuppressKeyboardChatter(event: event, keyboardManager: keyboardManager) {
        return nil
    }

    return Unmanaged.passRetained(event)
}

@discardableResult
func shouldSuppressKeyboardChatter(event: CGEvent, keyboardManager: KeyboardManager) -> Bool {
    guard keyboardManager.keyboardChatterFilterEnabled, event.type == .keyDown else {
        return false
    }

    guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
        return false
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    return keyboardManager.shouldSuppressKeyboardChatter(keyCode: keyCode, timestamp: event.timestamp)
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
