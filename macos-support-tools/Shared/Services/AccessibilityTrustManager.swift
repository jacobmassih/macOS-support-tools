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

    @ObservationIgnored private var trustChangeHandler: ((Bool) -> Void)?

    func refresh(prompt: Bool = false) {
        let shouldPrompt = prompt && !AXIsProcessTrusted()
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: shouldPrompt
        ] as CFDictionary

        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func setTrustChangeHandler(_ handler: @escaping (Bool) -> Void) {
        trustChangeHandler = handler
        handler(accessibilityTrusted)
    }

    func clearTrustChangeHandler() {
        trustChangeHandler = nil
    }

    private func notifyTrustChange() {
        trustChangeHandler?(accessibilityTrusted)
    }
}
