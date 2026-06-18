import CoreGraphics

struct KeyboardChatterFilter {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        debounceNanoseconds: UInt64
    ) -> Bool {
        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        guard timestamp - previousTimestamp <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            return false
        }

        return true
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
    }
}
