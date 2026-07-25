import CoreGraphics
import Foundation
import Observation

@Observable class KeyboardManager {
    enum DefaultsKey {
        static let keyboardDebounceEnabled = "KeyboardDebounceEnabled"
        static let keyboardDebounceDelayMilliseconds = "KeyboardDebounceDelayMilliseconds"
    }

    enum Defaults {
        static let keyboardDebounceDelayMilliseconds = 45.0
    }

    var keyboardDebounceEnabled = false {
        didSet {
            userDefaults.set(keyboardDebounceEnabled, forKey: DefaultsKey.keyboardDebounceEnabled)
            updateKeyboardEventTap()
            resetKeyboardDebounceFilter()
        }
    }
    var keyboardDebounceDelayMilliseconds = Defaults.keyboardDebounceDelayMilliseconds {
        didSet {
            let clampedDelayMilliseconds = keyboardDebounceDelayMilliseconds.clamped(to: 5...100)
            guard keyboardDebounceDelayMilliseconds == clampedDelayMilliseconds else {
                keyboardDebounceDelayMilliseconds = clampedDelayMilliseconds
                return
            }

            userDefaults.set(
                keyboardDebounceDelayMilliseconds,
                forKey: DefaultsKey.keyboardDebounceDelayMilliseconds
            )
        }
    }
    var keyboardBlocked = false {
        didSet {
            updateKeyboardEventTap()
        }
    }
    var tapStatus = "Inactive"

    private let userDefaults: UserDefaults
    @ObservationIgnored private var isAccessibilityEnabled = false
    @ObservationIgnored private let accessibilityManager: AccessibilityManager
    @ObservationIgnored private var hasStartedSystemServices = false
    @ObservationIgnored private var accessibilityPermissionObserverID: UUID?
    @ObservationIgnored private var keyboardDebounceFilter = KeyboardDebounceFilter()
    @ObservationIgnored private var keyboardEventTap: CFMachPort?
    @ObservationIgnored private var keyboardRunLoopSource: CFRunLoopSource?
    @ObservationIgnored private var keyboardEventMask: CGEventMask?

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
            DefaultsKey.keyboardDebounceEnabled: false,
            DefaultsKey.keyboardDebounceDelayMilliseconds: Defaults.keyboardDebounceDelayMilliseconds
        ])

        keyboardDebounceEnabled = userDefaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
        keyboardDebounceDelayMilliseconds = userDefaults.double(
            forKey: DefaultsKey.keyboardDebounceDelayMilliseconds
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

    internal func updateTapStatus() {
        if !isAccessibilityEnabled {
            tapStatus = "Inactive - Accessibility permission required"
        } else if !keyboardBlocked && !keyboardDebounceEnabled {
            tapStatus = "Inactive - No keyboard features enabled"
        } else if keyboardEventTap != nil {
            tapStatus = "Active"
        } else {
            tapStatus = "Inactive - Event tap unavailable"
        }
    }

    private func updateKeyboardEventTap() {
        defer { updateTapStatus() }

        guard hasStartedSystemServices else { return }

        guard (keyboardBlocked || keyboardDebounceEnabled) && isAccessibilityEnabled else {
            disableKeyboardEventTap()
            return
        }

        let eventMask = keyboardEventMaskForCurrentFeatures()
        if keyboardEventTap == nil {
            setupKeyboardEventTap(eventMask: eventMask)
        } else if keyboardEventMask != eventMask {
            disableKeyboardEventTap()
            setupKeyboardEventTap(eventMask: eventMask)
        }
    }

    private func keyboardEventMaskForCurrentFeatures() -> CGEventMask {
        var eventMask = (1 << CGEventType.keyDown.rawValue)

        if keyboardBlocked {
            eventMask |= (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        }

        return CGEventMask(eventMask)
    }

    private func setupKeyboardEventTap(eventMask: CGEventMask) {
        guard keyboardEventTap == nil else { return }

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
        guard let keyboardRunLoopSource else {
            disableKeyboardEventTap()
            return
        }

        keyboardEventMask = eventMask
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
    }

    fileprivate func reenableKeyboardEventTap() {
        guard let keyboardEventTap else { return }
        CGEvent.tapEnable(tap: keyboardEventTap, enable: true)
    }

    /// `.tapDisabledByUserInput` is user-initiated, so it is the one way out of a
    /// full keyboard block that does not depend on the mouse. Releasing the block
    /// takes priority over keeping the tap alive; silently re-arming it would
    /// defeat the escape. Debounce is not a lockout, so it just gets its tap back.
    fileprivate func handleUserInitiatedTapDisable() {
        guard keyboardBlocked else {
            print("[KeyboardManager] Keyboard tap disabled by user input; re-enabling for debounce.")
            reenableKeyboardEventTap()
            return
        }

        print("[KeyboardManager] Keyboard tap disabled by user input; releasing keyboard block.")

        // Hop off the tap callback: clearing the flag tears this tap down, and
        // invalidating a mach port from inside its own callout is best avoided.
        DispatchQueue.main.async { [weak self] in
            self?.keyboardBlocked = false
        }
    }

    private func disableKeyboardEventTap() {
        if let keyboardEventTap {
            CGEvent.tapEnable(tap: keyboardEventTap, enable: false)
            CFMachPortInvalidate(keyboardEventTap)
            self.keyboardEventTap = nil
        }
        keyboardEventMask = nil

        if let keyboardRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), keyboardRunLoopSource, .commonModes)
            self.keyboardRunLoopSource = nil
        }
    }

    fileprivate func shouldSuppressKeyboardEvent(_ event: CGEvent, type: CGEventType) -> Bool {
        if keyboardBlocked {
            return true
        }

        guard keyboardDebounceEnabled else {
            return false
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard type == .keyDown else {
            return false
        }

        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        return keyboardDebounceFilter.shouldSuppressKeyDown(
            keyCode: keyCode,
            timestamp: event.timestamp,
            isAutorepeat: isAutorepeat,
            debounceNanoseconds: UInt64(keyboardDebounceDelayMilliseconds * 1_000_000)
        )
    }

    private func resetKeyboardDebounceFilter() {
        keyboardDebounceFilter.reset()
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

    if type == .tapDisabledByUserInput {
        keyboardManager.handleUserInitiatedTapDisable()
        return Unmanaged.passRetained(event)
    }

    if type == .tapDisabledByTimeout {
        print("[KeyboardManager] Keyboard tap disabled by timeout; re-enabling.")
        keyboardManager.reenableKeyboardEventTap()
        return Unmanaged.passRetained(event)
    }

    if keyboardManager.shouldSuppressKeyboardEvent(event, type: type) {
        return nil
    }

    return Unmanaged.passRetained(event)
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
