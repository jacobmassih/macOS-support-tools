import CoreGraphics
import Foundation

/// The dedicated run loop that services this app's event taps.
///
/// An active tap holds up every event it masks until its callback returns, so
/// whichever run loop services a tap becomes a prerequisite for input across the
/// whole login session. On the main run loop that put SwiftUI rendering, AppKit
/// layout, and debugger pauses in the path of every keystroke, and any stall
/// there froze the desktop until the system disabled the tap for timing out.
/// This thread does nothing else, so the callbacks are never queued behind UI
/// work.
///
/// The instance lives for the process lifetime; there is no stop path because a
/// half-torn-down tap run loop is worse than an idle one.
nonisolated final class EventTapThread: @unchecked Sendable {
    static let shared = EventTapThread()

    private let readyCondition = NSCondition()
    private var thread: Thread?
    private var runLoop: CFRunLoop?

    private var isCurrent: Bool {
        Thread.current === thread
    }

    /// The run loop taps must be scheduled on. Blocks until the thread is up.
    private var targetRunLoop: CFRunLoop {
        readyCondition.lock()
        defer { readyCondition.unlock() }

        while runLoop == nil {
            readyCondition.wait()
        }

        return runLoop!
    }

    private init() {
        let thread = Thread { [weak self] in
            self?.runUntilProcessExit()
        }
        thread.name = "com.mst.macos-support-tools.event-tap"
        // Input handling is as latency-sensitive as work gets: anything less and
        // the callback can be descheduled long enough to trip the tap watchdog.
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    /// Runs `work` on the tap thread and waits for it to finish.
    ///
    /// Waiting is what makes teardown safe: once `uninstall` returns, the thread
    /// that would run the callback has already moved past it, so a tap can never
    /// fire against a deallocated `refcon`. Calls already on the tap thread run
    /// inline, so re-entering from inside a callback cannot deadlock.
    func performAndWait(_ work: () -> Void) {
        guard !isCurrent else {
            work()
            return
        }

        let runLoop = targetRunLoop
        let finished = DispatchSemaphore(value: 0)

        withoutActuallyEscaping(work) { work in
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
                work()
                finished.signal()
            }
            CFRunLoopWakeUp(runLoop)
            finished.wait()
        }
    }

    private func runUntilProcessExit() {
        readyCondition.lock()
        runLoop = CFRunLoopGetCurrent()
        readyCondition.broadcast()
        readyCondition.unlock()

        // A run loop with no input sources returns immediately, which would spin
        // this thread; the port never fires and exists only to hold it open.
        RunLoop.current.add(NSMachPort(), forMode: .common)

        while true {
            CFRunLoopRun()
        }
    }
}
