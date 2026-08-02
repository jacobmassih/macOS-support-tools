import CoreGraphics

enum KeyboardTapStatus: Equatable {
    case active
    case idle
    case accessibilityRequired
    case unavailable
    case disabledAfterRepeatedTimeouts

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .idle: return "Idle - No keyboard features enabled"
        case .accessibilityRequired: return "Inactive - Accessibility permission required"
        case .unavailable: return "Inactive - Event tap unavailable"
        case .disabledAfterRepeatedTimeouts: return "Disabled - Event tap kept timing out"
        }
    }
}

nonisolated struct KeyboardDebounceFilter: Sendable {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        let deltaNanoseconds = timestamp - previousTimestamp

        if isAutorepeat {
            return false
        }

        guard deltaNanoseconds <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        return true
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
    }
}
