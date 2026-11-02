import Foundation
import Testing
@testable import macos_support_tools

struct CleanupCancellationTests {
    private func category() -> CleanupCategory {
        CleanupCategory(id: .userCaches, title: "Fixture", subtitle: "", systemImage: "folder",
                        paths: [URL(filePath: "/nonexistent-cleanup-fixture")], riskLevel: .safe)
    }

    @Test @MainActor func cancellingScanPreservesCompletedResultsAndRejectsOverlappingWork() async {
        let gate = CleanupTestGate(blockOnCall: 2)
        let manager = CleanupManager(fileClient: CleanupFileClient(
            fileExists: { _ in true },
            contentsOfDirectory: { _ in gate.enter(); return [] }
        ), categories: [category()])
        await manager.scan()
        let previousDate = manager.lastScanDate
        let previousIDs = manager.scanResults.map(\.id)

        let scan = Task { await manager.scan() }
        await gate.waitForEntry()
        #expect(manager.isScanning)
        await manager.scan()
        await manager.clean(items: [])
        await manager.clearAllCaches()
        #expect(gate.calls == 2)
        #expect(manager.lastCleanupResult == nil)
        manager.cancelScan()
        gate.release()
        await scan.value

        #expect(!manager.isScanning)
        #expect(manager.lastError == nil)
        #expect(manager.lastScanDate == previousDate)
        #expect(manager.scanResults.map(\.id) == previousIDs)
        await manager.scan()
        #expect(gate.calls == 3)
        #expect(!manager.isScanning)
    }

    @Test @MainActor func callerCancellationCancelsTraversalWithoutPublishingResults() async {
        let gate = CleanupTestGate()
        let manager = CleanupManager(fileClient: CleanupFileClient(
            fileExists: { _ in true },
            contentsOfDirectory: { _ in gate.enter(); return [] }
        ), categories: [category()])
        let scan = Task { await manager.scan() }
        await gate.waitForEntry()
        scan.cancel()
        gate.release()
        await scan.value
        #expect(!manager.isScanning)
        #expect(manager.scanResults.isEmpty)
        #expect(manager.lastScanDate == nil)
        #expect(manager.lastError == nil)
    }

    @Test @MainActor func cleaningRejectsScansAndAdditionalCleanup() async {
        let gate = CleanupTestGate()
        let manager = CleanupManager(fileClient: CleanupFileClient(
            fileExists: { _ in true }, isDeletable: { _ in true },
            contentsOfDirectory: { _ in Issue.record("Scan must not start while cleaning"); return [] },
            trashItem: { _ in gate.enter() }
        ), categories: [category()])
        let item = CleanupItem(url: URL(filePath: "/fixture"), size: 1, modifiedDate: nil)
        let clean = Task { await manager.clean(items: [item]) }
        await gate.waitForEntry()
        #expect(manager.isCleaning)
        await manager.scan()
        await manager.clean(items: [item])
        await manager.clearAllCaches()
        #expect(gate.calls == 1)
        #expect(!manager.isScanning)
        #expect(manager.lastError == nil)
        gate.release()
        await clean.value
        #expect(!manager.isCleaning)
        #expect(manager.lastCleanupResult?.trashedItems.count == 1)
    }

    @Test @MainActor func alreadyCancelledCallerDoesNotStartScan() async {
        let manager = CleanupManager(categories: [category()])
        await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await manager.scan()
        }.value
        #expect(!manager.isScanning)
        #expect(manager.lastScanDate == nil)
        #expect(manager.lastError == nil)
    }

    @Test func cancellationFromDirectoryReadIsNotReportedAsAccessFailure() throws {
        #expect(throws: CancellationError.self) {
            try CleanupManager.scan(category: category(), fileClient: CleanupFileClient(
                fileExists: { _ in true },
                contentsOfDirectory: { _ in throw CancellationError() }
            ))
        }
    }
}

/// Holds one simulated filesystem call until the test has exercised cancellation
/// or reentrancy. The stream provides a deterministic handshake without sleeps.
private final class CleanupTestGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private let entered: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let blockOnCall: Int
    private var callCount = 0

    init(blockOnCall: Int = 1) {
        self.blockOnCall = blockOnCall
        (entered, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    var calls: Int { lock.withLock { callCount } }

    func enter() {
        let shouldBlock = lock.withLock {
            callCount += 1
            return callCount == blockOnCall
        }
        guard shouldBlock else { return }
        continuation.yield(())
        continuation.finish()
        if semaphore.wait(timeout: .now() + 15) == .timedOut {
            Issue.record("Test did not release the filesystem operation")
        }
    }

    func waitForEntry() async {
        for await _ in entered { return }
    }

    func release() { semaphore.signal() }
}
