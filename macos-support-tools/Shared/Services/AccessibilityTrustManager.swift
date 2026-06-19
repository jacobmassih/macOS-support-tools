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
