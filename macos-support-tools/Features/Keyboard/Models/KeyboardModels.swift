import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]
    private var pressedKeyCodes: Set<Int64> = []
    private var repeatingKeyCodes: Set<Int64> = []

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            return false
        }

        if isAutorepeat {
            if pressedKeyCodes.contains(keyCode),
               !repeatingKeyCodes.contains(keyCode),
               timestamp - previousTimestamp <= debounceNanoseconds {
                return true
            }

            repeatingKeyCodes.insert(keyCode)
            return false
        }

        guard pressedKeyCodes.contains(keyCode), timestamp - previousTimestamp <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            return false
        }

        return true
    }

    mutating func keyDidRelease(keyCode: Int64) {
        pressedKeyCodes.remove(keyCode)
        repeatingKeyCodes.remove(keyCode)
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
        pressedKeyCodes.removeAll()
        repeatingKeyCodes.removeAll()
    }
}
