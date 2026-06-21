import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]
    private var repeatingKeyCodes: Set<Int64> = []

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64
    ) -> Bool {
        guard let previousTimestamp = lastTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        if isAutorepeat {
            if !repeatingKeyCodes.contains(keyCode), timestamp - previousTimestamp <= debounceNanoseconds {
                return true
            }

            repeatingKeyCodes.insert(keyCode)
            return false
        }

        guard timestamp - previousTimestamp <= debounceNanoseconds else {
            lastTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        return true
    }

    mutating func keyDidRelease(keyCode: Int64, timestamp: CGEventTimestamp) {
        lastTimestampByKeyCode[keyCode] = timestamp
        repeatingKeyCodes.remove(keyCode)
    }

    mutating func reset() {
        lastTimestampByKeyCode.removeAll()
        repeatingKeyCodes.removeAll()
    }
}
