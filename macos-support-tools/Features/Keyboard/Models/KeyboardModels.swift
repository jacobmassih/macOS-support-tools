import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]
    private var keyDownKeyCodes: Set<Int64> = []

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        let isKeyDown = keyDownKeyCodes.contains(keyCode)

        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            keyDownKeyCodes.insert(keyCode)
            return false
        }

        let deltaNanoseconds = timestamp - previousTimestamp

        if isAutorepeat {
            return false
        }

        guard isKeyDown, deltaNanoseconds <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            keyDownKeyCodes.insert(keyCode)
            return false
        }

        return true
    }

    mutating func handleKeyUp(keyCode: Int64) {
        keyDownKeyCodes.remove(keyCode)
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
        keyDownKeyCodes.removeAll()
    }
}
