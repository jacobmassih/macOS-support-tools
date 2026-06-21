import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]
    private var pressedKeyCodes: Set<Int64> = []

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        let wasPressed = pressedKeyCodes.contains(keyCode)

        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            return false
        }

        let deltaNanoseconds = timestamp - previousTimestamp

        if isAutorepeat {
            return false
        }

        guard wasPressed, deltaNanoseconds <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            return false
        }

        return true
    }

    mutating func keyDidRelease(keyCode: Int64) {
        pressedKeyCodes.remove(keyCode)
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
        pressedKeyCodes.removeAll()
    }
}
