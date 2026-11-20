import Foundation
import Testing
@testable import macos_support_tools

struct CleanupAccessTests {
    @Test @MainActor func readFailuresAreUnavailableForEveryCategory() async throws {
        for error in [
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
            NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
        ] {
            let categories = CleanupCategoryID.allCases.map { category($0, paths: [URL(filePath: "/cleanup-access-fixture/\($0.rawValue)")]) }
            let manager = CleanupManager(
                fileClient: CleanupFileClient(fileExists: { _ in true }, contentsOfDirectory: { _ in throw error }),
                categories: categories
            )
            await manager.scan()
            #expect(manager.scanResults.count == categories.count)
            #expect(manager.scanResults.allSatisfy { $0.isUnavailable })
            #expect(manager.scanResults.allSatisfy { $0.accessError?.contains(error.localizedDescription) == true })
            #expect(manager.incompleteCategories.map(\.id) == categories.map(\.id))
        }
    }

    @Test @MainActor func readableEmptyCategoryIsAvailableAndComplete() async {
        let manager = CleanupManager(
            fileClient: CleanupFileClient(fileExists: { _ in true }, contentsOfDirectory: { _ in [] }),
            categories: [category(.logs, paths: [URL(filePath: "/cleanup-empty-fixture")])]
        )
        await manager.scan()
        #expect(manager.scanResults.count == 1)
        #expect(manager.scanResults.first?.isUnavailable == false)
        #expect(manager.scanResults.first?.totalBytes == 0)
        #expect(manager.incompleteCategories.isEmpty)
    }

    @Test @MainActor func partialScanKeepsKnownBytesAndErrorAfterCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = root.appending(path: "payload")
        try Data(repeating: 1, count: 4096).write(to: payload)
        let blocked = root.appending(path: "blocked")
        let manager = CleanupManager(
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                contentsOfDirectory: { path in
                    if path == blocked { throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError) }
                    return [payload]
                },
                trashItem: { _ in }
            ),
            categories: [category(.logs, paths: [root, blocked])]
        )
        await manager.scan()
        let result = try #require(manager.scanResults.first)
        #expect(!result.isUnavailable)
        #expect(result.itemCount == 1)
        #expect(result.totalBytes > 0)
        #expect(manager.totalReclaimableBytes == result.totalBytes)
        #expect(manager.incompleteCategories.map(\.id) == [.logs])
        await manager.clean(items: result.items)
        #expect(manager.scanResults.first?.accessError == result.accessError)
        #expect(manager.scanResults.first?.isUnavailable == true)
        #expect(manager.incompleteCategories.map(\.id) == [.logs])
    }

    @MainActor @Test func permanentlyDeletesOnlyConfirmedTrashChildren() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appending(path: UUID().uuidString)
        let trash = root.appending(path: "Trash", directoryHint: .isDirectory)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let confirmed = trash.appending(path: "confirmed")
        let retained = trash.appending(path: "retained")
        let outside = root.appending(path: "outside")
        for url in [confirmed, retained, outside] {
            try Data(repeating: 1, count: 4096).write(to: url)
        }
        let manager = CleanupManager(categories: [category(.trash, paths: [trash])])
        await manager.scan()
        let scanned = try #require(manager.scanResults.first?.items.first { $0.url.lastPathComponent == "confirmed" })
        let unscanned = CleanupItem(url: outside, size: 4096, modifiedDate: nil)
        let restored = root.appending(path: "restored")
        try fm.moveItem(at: confirmed, to: restored)
        try Data(repeating: 2, count: 4096).write(to: confirmed)
        await manager.deleteTrashItems([scanned])
        #expect(manager.lastCleanupResult?.skippedItems.count == 1)
        #expect(try Data(contentsOf: confirmed) == Data(repeating: 2, count: 4096))
        try fm.removeItem(at: confirmed)
        try fm.moveItem(at: restored, to: confirmed)
        await manager.deleteTrashItems([scanned, unscanned])
        #expect(!fm.fileExists(atPath: confirmed.path))
        #expect(fm.fileExists(atPath: retained.path))
        #expect(fm.fileExists(atPath: outside.path))
        #expect(manager.lastCleanupResult?.permanentlyDeleted == true)
        #expect(manager.scanResults.first?.itemCount == 1)
    }

    private func category(_ id: CleanupCategoryID, paths: [URL]) -> CleanupCategory {
        CleanupCategory(id: id, title: id.rawValue, subtitle: "Fixture", systemImage: "folder", paths: paths, riskLevel: .review)
    }
}
