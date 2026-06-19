import AppKit
import Foundation
import Observation

@Observable final class AccessibilityTrustManager {
    var accessibilityTrusted = false {
        didSet {
            guard accessibilityTrusted != oldValue else { return }
            notifyObservers()
        }
    }

    @ObservationIgnored private var observers: [UUID: (Bool) -> Void] = [:]

    func refresh(prompt: Bool = false) {
        let shouldPrompt = prompt && !AXIsProcessTrusted()
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: shouldPrompt
        ] as CFDictionary

        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func addObserver(_ observer: @escaping (Bool) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(accessibilityTrusted)
        return id
    }

    func removeObserver(_ id: UUID?) {
        guard let id else { return }
        observers[id] = nil
    }

    private func notifyObservers() {
        for observer in observers.values {
            observer(accessibilityTrusted)
        }
    }
}
