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
            // The tap callback reads a published snapshot rather than this
            // property, so a new delay only takes effect once it is republished.
            updateKeyboardEventTap()
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
    @ObservationIgnored private(set) var eventTapController: KeyboardEventTapController!

    init(
        userDefaults: UserDefaults = .standard,
        accessibilityManager: AccessibilityManager
    ) {
        self.userDefaults = userDefaults
        self.accessibilityManager = accessibilityManager
        self.eventTapController = KeyboardEventTapController { [weak self] in
            // Hop to the main thread: the release runs on the tap thread, and
            // clearing the flag tears that very tap down.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.keyboardBlocked = false
                }
            }
        }
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
        eventTapController.uninstall()
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
        let settings = keyboardTapSettings()
        eventTapController.updateSettings(settings)

        guard hasStartedSystemServices else { return }

        guard settings.needsEventTap && isAccessibilityEnabled else {
            eventTapController.uninstall()
            return
        }

        eventTapController.install(eventMask: keyboardEventMaskForCurrentFeatures())
    }

    private func keyboardTapSettings() -> KeyboardTapSettings {
        KeyboardTapSettings(
            isBlocked: keyboardBlocked,
            isDebounceEnabled: keyboardDebounceEnabled,
            debounceNanoseconds: UInt64(keyboardDebounceDelayMilliseconds * 1_000_000)
        )
    }

    private func keyboardEventMaskForCurrentFeatures() -> CGEventMask {
        var eventMask = (1 << CGEventType.keyDown.rawValue)

        if keyboardBlocked {
            eventMask |= (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        }

        return CGEventMask(eventMask)
    }

    private func resetKeyboardDebounceFilter() {
        eventTapController.resetDebounceFilter()
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
