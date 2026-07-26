import Foundation

/// Sliding-window budget for system-initiated event tap timeouts.
///
/// The system disables a tap that times out, meaning its callback did not return
/// before the watchdog deadline. Re-arming unconditionally turns that into a
/// livelock: the re-armed tap stalls the next event, times out again, and input
/// keeps freezing while the log fills with retries. Once `budget` timeouts land
/// inside `windowSeconds`, the breaker trips and the tap stays down until reset.
nonisolated struct EventTapTimeoutBreaker: Sendable {
    static let budget = 5
    static let windowSeconds: TimeInterval = 60

    private(set) var isTripped = false
    private(set) var timeoutsInWindow = 0
    private var windowStart: TimeInterval?

    /// Records a timeout and reports whether the tap should be re-armed.
    ///
    /// - Parameter now: Monotonic seconds; only differences are meaningful.
    mutating func shouldReenable(at now: TimeInterval) -> Bool {
        guard !isTripped else { return false }

        if let windowStart, now - windowStart <= Self.windowSeconds {
            timeoutsInWindow += 1
        } else {
            windowStart = now
            timeoutsInWindow = 1
        }

        guard timeoutsInWindow <= Self.budget else {
            isTripped = true
            return false
        }

        return true
    }

    mutating func reset() {
        isTripped = false
        timeoutsInWindow = 0
        windowStart = nil
    }
}
