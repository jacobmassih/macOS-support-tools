import CoreGraphics

struct KeyboardDebounceFilter {
    private var lastKeyDownTimestampByKeyCode: [Int64: CGEventTimestamp] = [:]
    private var pressedKeyCodes: Set<Int64> = []
    private var repeatingKeyCodes: Set<Int64> = []

    mutating func shouldSuppressKeyDown(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        isAutorepeat: Bool = false,
        debounceNanoseconds: UInt64,
        debugLog: ((String) -> Void)? = nil
    ) -> Bool {
        let wasPressed = pressedKeyCodes.contains(keyCode)
        let wasRepeating = repeatingKeyCodes.contains(keyCode)

        guard let previousTimestamp = lastKeyDownTimestampByKeyCode[keyCode],
              timestamp >= previousTimestamp else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            debugLog?(
                "allow keyDown keyCode=\(keyCode) eventTimestamp=\(timestamp) autorepeat=\(isAutorepeat) reason=first-or-out-of-order"
            )
            return false
        }

        let deltaNanoseconds = timestamp - previousTimestamp
        let deltaMilliseconds = Double(deltaNanoseconds) / 1_000_000
        let debounceMilliseconds = Double(debounceNanoseconds) / 1_000_000

        if isAutorepeat {
            if wasPressed, !wasRepeating, deltaNanoseconds <= debounceNanoseconds {
                debugLog?(
                    "suppress keyDown keyCode=\(keyCode) eventTimestamp=\(timestamp) previousTimestamp=\(previousTimestamp) deltaMs=\(deltaMilliseconds) debounceMs=\(debounceMilliseconds) pressed=\(wasPressed) repeating=\(wasRepeating) autorepeat=true reason=early-autorepeat-duplicate"
                )
                return true
            }

            repeatingKeyCodes.insert(keyCode)
            debugLog?(
                "allow keyDown keyCode=\(keyCode) eventTimestamp=\(timestamp) previousTimestamp=\(previousTimestamp) deltaMs=\(deltaMilliseconds) debounceMs=\(debounceMilliseconds) pressed=\(wasPressed) repeating=\(wasRepeating) autorepeat=true reason=held-key-repeat"
            )
            return false
        }

        guard wasPressed, deltaNanoseconds <= debounceNanoseconds else {
            lastKeyDownTimestampByKeyCode[keyCode] = timestamp
            pressedKeyCodes.insert(keyCode)
            debugLog?(
                "allow keyDown keyCode=\(keyCode) eventTimestamp=\(timestamp) previousTimestamp=\(previousTimestamp) deltaMs=\(deltaMilliseconds) debounceMs=\(debounceMilliseconds) pressed=\(wasPressed) repeating=\(wasRepeating) autorepeat=false reason=\(wasPressed ? "outside-window" : "repress-after-release")"
            )
            return false
        }

        debugLog?(
            "suppress keyDown keyCode=\(keyCode) eventTimestamp=\(timestamp) previousTimestamp=\(previousTimestamp) deltaMs=\(deltaMilliseconds) debounceMs=\(debounceMilliseconds) pressed=\(wasPressed) repeating=\(wasRepeating) autorepeat=false reason=duplicate-keydown"
        )
        return true
    }

    mutating func keyDidRelease(
        keyCode: Int64,
        timestamp: CGEventTimestamp,
        debugLog: ((String) -> Void)? = nil
    ) {
        let wasPressed = pressedKeyCodes.contains(keyCode)
        let wasRepeating = repeatingKeyCodes.contains(keyCode)
        pressedKeyCodes.remove(keyCode)
        repeatingKeyCodes.remove(keyCode)
        debugLog?(
            "allow keyUp keyCode=\(keyCode) eventTimestamp=\(timestamp) pressed=\(wasPressed) repeating=\(wasRepeating) reason=release"
        )
    }

    mutating func reset() {
        lastKeyDownTimestampByKeyCode.removeAll()
        pressedKeyCodes.removeAll()
        repeatingKeyCodes.removeAll()
    }
}
