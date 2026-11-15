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

    private func category(_ id: CleanupCategoryID, paths: [URL]) -> CleanupCategory {
        CleanupCategory(id: id, title: id.rawValue, subtitle: "Fixture", systemImage: "folder", paths: paths, riskLevel: .review)
    }
}
