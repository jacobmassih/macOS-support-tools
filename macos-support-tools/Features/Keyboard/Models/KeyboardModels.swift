import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastKeyEventTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        guard let previousTimestamp = lastKeyEventTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyEventTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        let deltaNanoseconds = timestamp - previousTimestamp

        if isAutorepeat {
            return false
        }

        guard deltaNanoseconds <= debounceNanoseconds else {
            lastKeyEventTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        return true
    }

    mutating func handleKeyUp(keyCode: Int64, timestamp: CGEventTimestamp) {
        lastKeyEventTimestampByKeyCode[keyCode] = timestamp
    }

    mutating func reset() {
        lastKeyEventTimestampByKeyCode.removeAll()
    }
}
