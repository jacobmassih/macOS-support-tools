import AppKit
import Foundation
import Observation

@Observable final class AccessibilityTrustManager {
    var accessibilityTrusted = false {
        didSet {
            guard accessibilityTrusted != oldValue else { return }
            notifyTrustChange()
        }
    }

    @ObservationIgnored private var trustChangeHandlers: [UUID: (Bool) -> Void] = [:]
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

        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func addTrustChangeHandler(_ handler: @escaping (Bool) -> Void) -> UUID {
        let id = UUID()
        trustChangeHandlers[id] = handler
        handler(accessibilityTrusted)
        return id
    }

    func removeTrustChangeHandler(_ id: UUID) {
        trustChangeHandlers[id] = nil
    }

    private func notifyTrustChange() {
        for handler in trustChangeHandlers.values {
            handler(accessibilityTrusted)
        }
    }
}
