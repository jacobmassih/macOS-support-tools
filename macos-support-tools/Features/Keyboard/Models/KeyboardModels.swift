import CoreGraphics

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
