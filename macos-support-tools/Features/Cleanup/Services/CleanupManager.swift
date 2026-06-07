import Foundation
import Observation

@Observable
final class CleanupManager {
    private let fileClient: CleanupFileClient
    private let customCategories: [CleanupCategory]?

    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var scanResults: [CleanupScanResult] = []
    private(set) var lastScanDate: Date?
    private(set) var lastCleanupResult: CleanupRunResult?
    private(set) var lastError: String?

    var totalReclaimableBytes: Int64 {
        scanResults.reduce(0) { $0 + $1.totalBytes }
    }

    init(
        fileClient: CleanupFileClient = .live,
        categories: [CleanupCategory]? = nil
    ) {
        self.fileClient = fileClient
        self.customCategories = categories
    }

    var categories: [CleanupCategory] {
        customCategories ?? CleanupCatalog.defaultCategories()
    }

    @MainActor
    func scan() async {
        isScanning = true
        lastError = nil

        let categoriesToScan = categories

        do {
            let results = try await Task.detached(priority: .userInitiated) {
                try categoriesToScan.map { category in
                    try Self.scan(category: category)
                }
            }.value

            scanResults = results
            lastScanDate = Date()
        } catch {
            lastError = error.localizedDescription
        }

        isScanning = false
    }

    @MainActor
    func clean(items: [CleanupItem]) async {
        guard !items.isEmpty else {
            lastCleanupResult = CleanupRunResult(trashedItems: [], skippedItems: [])
            return
        }

        isCleaning = true
        lastError = nil

        let itemsToClean = items
        let fileClient = fileClient

        let result = await Task.detached(priority: .userInitiated) {
            Self.clean(items: itemsToClean, fileClient: fileClient)
        }.value

        lastCleanupResult = result

        if result.didTrashAnyItems {
            removeTrashedItemsFromScanResults(result.trashedItems)
        }

        isCleaning = false
    }

    @MainActor
    func clearAllCaches() async {
        guard let cacheCategory = categories.first(where: { $0.id == .userCaches }) else {
            lastCleanupResult = CleanupRunResult(trashedItems: [], skippedItems: [])
            return
        }

        let cacheResult: CleanupScanResult

        if let existingResult = scanResults.first(where: { $0.category.id == .userCaches }) {
            cacheResult = existingResult
        } else {
            cacheResult = (try? Self.scan(category: cacheCategory)) ?? CleanupScanResult(
                category: cacheCategory,
                totalBytes: 0,
                itemCount: 0,
                items: []
            )
        }

        await clean(items: cacheResult.items)
    }

    nonisolated static func scan(category: CleanupCategory) throws -> CleanupScanResult {
        let items = category.paths.flatMap { path -> [CleanupItem] in
            guard FileManager.default.fileExists(atPath: path.path) else {
                return []
            }

            return cleanupItems(in: path)
        }
        .sorted { $0.size > $1.size }

        return CleanupScanResult(
            category: category,
            totalBytes: items.reduce(0) { $0 + $1.size },
            itemCount: items.count,
            items: items
        )
    }

    nonisolated static func clean(
        items: [CleanupItem],
        fileClient: CleanupFileClient = .live
    ) -> CleanupRunResult {
        var trashedItems: [CleanupItem] = []
        var skippedItems: [CleanupSkippedItem] = []

        for item in items {
            guard fileClient.fileExists(item.url) else {
                skippedItems.append(CleanupSkippedItem(item: item, reason: "Item no longer exists."))
                continue
            }

            guard fileClient.isDeletable(item.url) else {
                skippedItems.append(CleanupSkippedItem(item: item, reason: "Permission denied."))
                continue
            }

            do {
                try fileClient.trashItem(item.url)
                trashedItems.append(item)
            } catch {
                skippedItems.append(CleanupSkippedItem(item: item, reason: error.localizedDescription))
            }
        }

        return CleanupRunResult(trashedItems: trashedItems, skippedItems: skippedItems)
    }

    @MainActor
    private func removeTrashedItemsFromScanResults(_ trashedItems: [CleanupItem]) {
        let trashedURLs = Set(trashedItems.map(\.url))

        scanResults = scanResults.map { result in
            let remainingItems = result.items.filter { !trashedURLs.contains($0.url) }

            return CleanupScanResult(
                category: result.category,
                totalBytes: remainingItems.reduce(0) { $0 + $1.size },
                itemCount: remainingItems.count,
                items: remainingItems
            )
        }
    }

    nonisolated private static func cleanupItems(in directoryURL: URL) -> [CleanupItem] {
        guard let childURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            return [
                CleanupItem(
                    url: directoryURL,
                    size: folderSize(at: directoryURL),
                    modifiedDate: modifiedDate(for: directoryURL)
                )
            ]
        }

        return childURLs.map { url in
            CleanupItem(
                url: url,
                size: folderSize(at: url),
                modifiedDate: modifiedDate(for: url)
            )
        }
    }

    nonisolated private static func folderSize(at url: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return fileSize(at: url)
        }

        var totalBytes: Int64 = fileSize(at: url)

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }

            if values.isRegularFile == true {
                totalBytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }

        return totalBytes
    }

    nonisolated private static func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return 0
        }

        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    nonisolated private static func modifiedDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
