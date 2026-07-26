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
        static let keyboardDebounceDelayMillisecondsRange = 5.0...100.0
    }

    var keyboardDebounceEnabled: Bool {
        didSet {
            userDefaults.set(keyboardDebounceEnabled, forKey: DefaultsKey.keyboardDebounceEnabled)
            updateKeyboardEventTap()
            resetKeyboardDebounceFilter()
        }
    }
    var keyboardDebounceDelayMilliseconds: Double {
        didSet {
            let clampedDelayMilliseconds = keyboardDebounceDelayMilliseconds
                .clamped(to: Defaults.keyboardDebounceDelayMillisecondsRange)
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

    private let userDefaults: UserDefaults
    @ObservationIgnored private var isAccessibilityEnabled = false
    @ObservationIgnored private let accessibilityManager: AccessibilityManager
    @ObservationIgnored private var hasStartedSystemServices = false
    @ObservationIgnored private var accessibilityPermissionObserverID: UUID?
    @ObservationIgnored private var keyboardDebounceFilter = KeyboardDebounceFilter()
    @ObservationIgnored private let keyboardTap = EventTap()
    @ObservationIgnored private var keyboardEventMask: CGEventMask?

    init(
        userDefaults: UserDefaults = .standard,
        accessibilityManager: AccessibilityManager
    ) {
        self.userDefaults = userDefaults
        self.accessibilityManager = accessibilityManager

        userDefaults.register(defaults: [
            DefaultsKey.keyboardDebounceEnabled: false,
            DefaultsKey.keyboardDebounceDelayMilliseconds: Defaults.keyboardDebounceDelayMilliseconds
        ])

        // These are initialised, not assigned, so the `didSet` observers stay
        // silent: assigning would write the registered fallbacks back into the
        // persistent domain and turn a code-owned default into a stored value
        // the user never chose. Initialisation also skips the observer's clamp,
        // so a persisted out-of-range delay is clamped explicitly here.
        self.keyboardDebounceEnabled = userDefaults.bool(forKey: DefaultsKey.keyboardDebounceEnabled)
        self.keyboardDebounceDelayMilliseconds = userDefaults
            .double(forKey: DefaultsKey.keyboardDebounceDelayMilliseconds)
            .clamped(to: Defaults.keyboardDebounceDelayMillisecondsRange)

        accessibilityPermissionObserverID = accessibilityManager.observePermissionChanges { [weak self] isAccessibilityEnabled in
            self?.handleAccessibilityPermissionDidChange(isAccessibilityEnabled)
        }
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

        guard (keyboardBlocked || keyboardDebounceEnabled) && isAccessibilityEnabled else {
            disableKeyboardEventTap()
            return
        }

        let eventMask = keyboardEventMaskForCurrentFeatures()
        if !keyboardTap.isInstalled {
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
        guard !keyboardTap.isInstalled else { return }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard keyboardTap.install(
            eventMask: eventMask,
            callback: keyboardEventCallback,
            userInfo: context
        ) else {
            print("Failed to create keyboard event tap. App may need accessibility permissions.")
            return
        }

        keyboardEventMask = eventMask
    }

    fileprivate func reenableKeyboardEventTap() {
        keyboardTap.reenable()
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
        keyboardTap.uninstall()
        keyboardEventMask = nil
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
