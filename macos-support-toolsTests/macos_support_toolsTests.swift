import Foundation
import Testing
@testable import macos_support_tools

struct macos_support_toolsTests {

    @Test func cleanupScanIncludesPackageDescendantSizes() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let appBundleURL = rootURL.appending(path: "LargeFixture.app", directoryHint: .isDirectory)
        let payloadDirectoryURL = appBundleURL.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        let payloadURL = payloadDirectoryURL.appending(path: "payload.bin")
        let payload = Data(repeating: 0xAB, count: 16 * 1024)

        try fileManager.createDirectory(at: payloadDirectoryURL, withIntermediateDirectories: true)
        try payload.write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let category = CleanupCategory(
            id: .trash,
            title: "Test Trash",
            subtitle: "Fixture category",
            systemImage: "trash",
            paths: [rootURL],
            riskLevel: .review
        )

        let result = try CleanupManager.scan(category: category)

        #expect(result.itemCount == 1)
        #expect(result.items.first?.url.resolvingSymlinksInPath() == appBundleURL.resolvingSymlinksInPath())
        #expect(result.totalBytes >= Int64(payload.count))
    }

    @Test func cleanupScanIgnoresZeroByteCandidates() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let emptyFileURL = rootURL.appending(path: "empty.tmp")
        let payloadURL = rootURL.appending(path: "payload.tmp")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data().write(to: emptyFileURL)
        try Data("payload".utf8).write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let category = CleanupCategory(
            id: .trash,
            title: "Test Trash",
            subtitle: "Fixture category",
            systemImage: "trash",
            paths: [rootURL],
            riskLevel: .review
        )

        let result = try CleanupManager.scan(category: category)

        #expect(result.itemCount == 1)
        #expect(result.items.map { $0.url.resolvingSymlinksInPath() } == [payloadURL.resolvingSymlinksInPath()])
        #expect(result.totalBytes > 0)
    }

    @Test func cleanupMovesDeletableItemsToTrash() throws {
        let firstURL = URL(filePath: "/tmp/cleanup-first")
        let secondURL = URL(filePath: "/tmp/cleanup-second")
        let firstItem = CleanupItem(url: firstURL, size: 1024, modifiedDate: nil)
        let secondItem = CleanupItem(url: secondURL, size: 2048, modifiedDate: nil)
        let recorder = TrashRecorder()

        let result = CleanupManager.clean(
            items: [firstItem, secondItem],
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { recorder.record($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [firstURL, secondURL])
        #expect(result.trashedBytes == 3072)
        #expect(result.skippedItems.isEmpty)
        #expect(recorder.urls == [firstURL, secondURL])
    }

    @Test func cleanupSkipsMissingAndPermissionDeniedItems() throws {
        let missingURL = URL(filePath: "/tmp/missing")
        let deniedURL = URL(filePath: "/tmp/denied")
        let allowedURL = URL(filePath: "/tmp/allowed")
        let missingItem = CleanupItem(url: missingURL, size: 1, modifiedDate: nil)
        let deniedItem = CleanupItem(url: deniedURL, size: 2, modifiedDate: nil)
        let allowedItem = CleanupItem(url: allowedURL, size: 4, modifiedDate: nil)
        let recorder = TrashRecorder()

        let result = CleanupManager.clean(
            items: [missingItem, deniedItem, allowedItem],
            fileClient: CleanupFileClient(
                fileExists: { $0 != missingURL },
                isDeletable: { $0 != deniedURL },
                trashItem: { recorder.record($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [allowedURL])
        #expect(result.skippedItems.map { $0.item.url } == [missingURL, deniedURL])
        #expect(result.skippedItems.map(\.reason) == ["Item no longer exists.", "Permission denied."])
        #expect(result.skippedBytes == 3)
        #expect(recorder.urls == [allowedURL])
    }

    @Test func cleanupReportsTrashErrorsAndContinues() throws {
        let failingURL = URL(filePath: "/tmp/failing")
        let succeedingURL = URL(filePath: "/tmp/succeeding")
        let failingItem = CleanupItem(url: failingURL, size: 8, modifiedDate: nil)
        let succeedingItem = CleanupItem(url: succeedingURL, size: 16, modifiedDate: nil)
        let recorder = TrashRecorder(failingURLs: [failingURL])

        let result = CleanupManager.clean(
            items: [failingItem, succeedingItem],
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { try recorder.recordOrThrow($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [succeedingURL])
        #expect(result.skippedItems.map { $0.item.url } == [failingURL])
        #expect(result.skippedItems.first?.reason == "Trash failed for failing")
        #expect(recorder.urls == [failingURL, succeedingURL])
    }

    @Test func cleanupLiveClientMovesDisposableFileToTrash() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let disposableURL = rootURL.appending(path: "disposable-cleanup-file.txt")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("trash me".utf8).write(to: disposableURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let result = CleanupManager.clean(
            items: [
                CleanupItem(url: disposableURL, size: 8, modifiedDate: nil)
            ]
        )

        #expect(result.trashedItems.map(\.url) == [disposableURL])
        #expect(result.skippedItems.isEmpty)
        #expect(!fileManager.fileExists(atPath: disposableURL.path))
    }

    @Test @MainActor func cleanupManagerScansCustomCategoriesAndTracksTotals() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cacheDirectoryURL = rootURL.appending(path: "CacheBucket", directoryHint: .isDirectory)
        let payloadURL = cacheDirectoryURL.appending(path: "payload.bin")
        let payload = Data(repeating: 0xCD, count: 4096)

        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try payload.write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(categories: [
            CleanupCategory(
                id: .userCaches,
                title: "Caches",
                subtitle: "Test caches",
                systemImage: "shippingbox",
                paths: [rootURL],
                riskLevel: .safe
            )
        ])

        await manager.scan()

        #expect(!manager.isScanning)
        #expect(manager.lastError == nil)
        #expect(manager.lastScanDate != nil)
        #expect(manager.categories.count == 1)
        #expect(manager.scanResults.count == 1)
        #expect(manager.scanResults.first?.items.first?.url.resolvingSymlinksInPath() == cacheDirectoryURL.resolvingSymlinksInPath())
        #expect(manager.totalReclaimableBytes >= Int64(payload.count))
    }

    @Test @MainActor func cleanupManagerCleanRecordsResultAndRemovesTrashedScanItems() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let firstURL = rootURL.appending(path: "first.tmp")
        let secondURL = rootURL.appending(path: "second.tmp")
        let recorder = TrashRecorder()

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { $0.resolvingSymlinksInPath() == firstURL.resolvingSymlinksInPath() },
                trashItem: { recorder.record($0) }
            ),
            categories: [
                CleanupCategory(
                    id: .temporaryFiles,
                    title: "Temporary",
                    subtitle: "Test temporary files",
                    systemImage: "clock",
                    paths: [rootURL],
                    riskLevel: .safe
                )
            ]
        )

        await manager.scan()
        await manager.clean(items: manager.scanResults.flatMap(\.items))

        #expect(!manager.isCleaning)
        #expect(manager.lastCleanupResult?.trashedItems.map { $0.url.resolvingSymlinksInPath() } == [firstURL.resolvingSymlinksInPath()])
        #expect(manager.lastCleanupResult?.skippedItems.map { $0.item.url.resolvingSymlinksInPath() } == [secondURL.resolvingSymlinksInPath()])
        #expect(manager.scanResults.first?.items.map { $0.url.resolvingSymlinksInPath() } == [secondURL.resolvingSymlinksInPath()])
        #expect(manager.totalReclaimableBytes == manager.scanResults.first?.totalBytes)
        #expect(recorder.urls.map { $0.resolvingSymlinksInPath() } == [firstURL.resolvingSymlinksInPath()])
    }

    @Test @MainActor func cleanupManagerCleanHandlesEmptySelection() async {
        let manager = CleanupManager(categories: [])

        await manager.clean(items: [])

        #expect(manager.lastCleanupResult?.trashedItems.isEmpty == true)
        #expect(manager.lastCleanupResult?.skippedItems.isEmpty == true)
        #expect(!manager.isCleaning)
    }

    @Test @MainActor func cleanupManagerClearAllCachesOnlyCleansUserCaches() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cacheRootURL = rootURL.appending(path: "Caches", directoryHint: .isDirectory)
        let tempRootURL = rootURL.appending(path: "Temporary", directoryHint: .isDirectory)
        let cacheItemURL = cacheRootURL.appending(path: "cache-item")
        let tempItemURL = tempRootURL.appending(path: "temp-item")
        let recorder = TrashRecorder()

        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempRootURL, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cacheItemURL)
        try Data("temp".utf8).write(to: tempItemURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { recorder.record($0) }
            ),
            categories: [
                CleanupCategory(
                    id: .userCaches,
                    title: "Caches",
                    subtitle: "Test caches",
                    systemImage: "shippingbox",
                    paths: [cacheRootURL],
                    riskLevel: .safe
                ),
                CleanupCategory(
                    id: .temporaryFiles,
                    title: "Temporary",
                    subtitle: "Test temporary files",
                    systemImage: "clock",
                    paths: [tempRootURL],
                    riskLevel: .safe
                )
            ]
        )

        await manager.clearAllCaches()

        #expect(manager.lastCleanupResult?.trashedItems.map { $0.url.resolvingSymlinksInPath() } == [cacheItemURL.resolvingSymlinksInPath()])
        #expect(manager.lastCleanupResult?.skippedItems.isEmpty == true)
        #expect(recorder.urls.map { $0.resolvingSymlinksInPath() } == [cacheItemURL.resolvingSymlinksInPath()])
    }

    @Test @MainActor func cleanupManagerDefaultCategoriesSelectExpectedPaths() {
        let manager = CleanupManager()
        let categoryIDs = manager.categories.map(\.id)

        #expect(categoryIDs == CleanupCategoryID.allCases)
        #expect(manager.categories.first?.paths.first?.lastPathComponent == "Caches")
        #expect(manager.categories.contains { $0.id == .temporaryFiles && $0.paths.count == 2 })
        #expect(manager.categories.contains { $0.id == .trash && $0.riskLevel == .review })
    }

    @Test func cleanupCatalogDefaultCategoriesStayInModelOrder() {
        let categories = CleanupCatalog.defaultCategories()

        #expect(categories.map(\.id) == CleanupCategoryID.allCases)
        #expect(categories.first?.paths.first?.lastPathComponent == "Caches")
        #expect(categories.contains { $0.id == .temporaryFiles && $0.paths.count == 2 })
        #expect(categories.contains { $0.id == .trash && $0.riskLevel == .review })
    }

    @Test func mouseDeviceStoreRoundTripsDeviceSettings() throws {
        let suiteName = "MouseDeviceStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = MouseDeviceStore(userDefaults: userDefaults)
        let device = MouseDevice(
            id: "123-456-location-789",
            name: "Test Mouse",
            vendorID: 123,
            productID: 456,
            naturalScrollEnabled: false,
            lastConnected: Date(timeIntervalSince1970: 1_234),
            leftButtonEnabled: true,
            rightButtonEnabled: true,
            middleButtonEnabled: true,
            button4Enabled: false,
            button5Enabled: true,
            button4Action: .middleClick,
            button5Action: .back
        )

        store.save([device.id: device])
        let loadedDevice = store.load()?[device.id]

        #expect(loadedDevice?.id == device.id)
        #expect(loadedDevice?.name == device.name)
        #expect(loadedDevice?.vendorID == device.vendorID)
        #expect(loadedDevice?.productID == device.productID)
        #expect(loadedDevice?.naturalScrollEnabled == device.naturalScrollEnabled)
        #expect(loadedDevice?.lastConnected == device.lastConnected)
        #expect(loadedDevice?.button4Enabled == device.button4Enabled)
        #expect(loadedDevice?.button4Action == device.button4Action)
        #expect(loadedDevice?.button5Action == device.button5Action)
    }

    @Test func cleanupRunResultComputedPropertiesSummarizeItems() {
        let moved = CleanupItem(url: URL(filePath: "/tmp/moved"), size: 10, modifiedDate: nil)
        let skipped = CleanupItem(url: URL(filePath: "/tmp/skipped"), size: 20, modifiedDate: nil)
        let emptyResult = CleanupRunResult(trashedItems: [], skippedItems: [])
        let result = CleanupRunResult(
            trashedItems: [moved],
            skippedItems: [
                CleanupSkippedItem(item: skipped, reason: "Nope")
            ]
        )

        #expect(!emptyResult.didTrashAnyItems)
        #expect(result.didTrashAnyItems)
        #expect(result.trashedBytes == 10)
        #expect(result.skippedBytes == 20)
        #expect(result.skippedItems.first?.id == skipped.url)
    }

    @Test func cleanupScanResultPreviewDetailsSummarizeCandidates() {
        let olderDate = Date(timeIntervalSince1970: 1_000)
        let newerDate = Date(timeIntervalSince1970: 2_000)
        let smallItem = CleanupItem(url: URL(filePath: "/tmp/small"), size: 10, modifiedDate: newerDate)
        let mediumItem = CleanupItem(url: URL(filePath: "/tmp/medium"), size: 20, modifiedDate: nil)
        let largeItem = CleanupItem(url: URL(filePath: "/tmp/large"), size: 30, modifiedDate: olderDate)
        let category = CleanupCategory(
            id: .temporaryFiles,
            title: "Temporary",
            subtitle: "Temporary fixtures",
            systemImage: "clock",
            paths: [URL(filePath: "/tmp")],
            riskLevel: .safe
        )
        let scanResult = CleanupScanResult(
            category: category,
            totalBytes: 60,
            itemCount: 3,
            items: [smallItem, mediumItem, largeItem]
        )

        #expect(scanResult.largestItem?.url == largeItem.url)
        #expect(scanResult.mostRecentModifiedDate == newerDate)
        #expect(scanResult.oldestModifiedDate == olderDate)
        #expect(scanResult.previewItems(limit: 2).map(\.url) == [largeItem.url, mediumItem.url])
    }

    @Test func cleanupModelIdentifiersAndRiskDescriptionsAreStable() {
        let item = CleanupItem(url: URL(filePath: "/tmp/model-item"), size: 1, modifiedDate: nil)
        let category = CleanupCategory(
            id: .logs,
            title: "Logs",
            subtitle: "Diagnostic logs",
            systemImage: "doc.text",
            paths: [URL(filePath: "/tmp/logs")],
            riskLevel: .review
        )
        let scanResult = CleanupScanResult(
            category: category,
            totalBytes: item.size,
            itemCount: 1,
            items: [item]
        )

        #expect(CleanupCategoryID.logs.id == "logs")
        #expect(CleanupRiskLevel.safe.description == "Usually safe to remove and commonly recreated by apps.")
        #expect(CleanupRiskLevel.review.description == "Worth reviewing before cleanup because contents can be useful.")
        #expect(item.id == item.url)
        #expect(scanResult.id == .logs)
    }
}

private final class TrashRecorder: @unchecked Sendable {
    private(set) var urls: [URL] = []
    private let failingURLs: Set<URL>

    init(failingURLs: Set<URL> = []) {
        self.failingURLs = failingURLs
    }

    func record(_ url: URL) {
        urls.append(url)
    }

    func recordOrThrow(_ url: URL) throws {
        record(url)

        if failingURLs.contains(url) {
            throw TrashRecorderError(url: url)
        }
    }
}

private struct TrashRecorderError: LocalizedError {
    let url: URL

    var errorDescription: String? {
        "Trash failed for \(url.lastPathComponent)"
    }
}
