import AppKit
import Foundation
import Observation

@Observable final class AccessibilityManager {
    var isAccessibilityEnabled = false {
        didSet {
            guard isAccessibilityEnabled != oldValue else { return }
            notifyPermissionChange()
        }
    }

    @ObservationIgnored private var permissionChangeHandlers: [UUID: (Bool) -> Void] = [:]
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var appActivationObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        appActivationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let appActivationObserver {
            notificationCenter.removeObserver(appActivationObserver)
        }
    }

    func refresh(prompt: Bool = false) {
        let shouldPrompt = prompt && !AXIsProcessTrusted()
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: shouldPrompt
        ] as CFDictionary

        isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options)
    }

    func observePermissionChanges(_ handler: @escaping (Bool) -> Void) -> UUID {
        let id = UUID()
        permissionChangeHandlers[id] = handler
        handler(isAccessibilityEnabled)
        return id
    }

    func removePermissionChangeHandler(_ id: UUID) {
        permissionChangeHandlers[id] = nil
    }

    private func notifyPermissionChange() {
        for handler in permissionChangeHandlers.values {
            handler(isAccessibilityEnabled)
        }
    }
}
