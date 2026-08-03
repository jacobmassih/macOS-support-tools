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

    var canClearAllCaches: Bool {
        scanResults.contains { $0.category.id == .userCaches }
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
            // Categories walk unrelated trees, so they scan concurrently. Results are
            // reassembled by index because completion order is not category order.
            let results = try await withThrowingTaskGroup(
                of: (offset: Int, result: CleanupScanResult).self
            ) { group in
                for (offset, category) in categoriesToScan.enumerated() {
                    group.addTask(priority: .userInitiated) {
                        (offset, try Self.scan(category: category))
                    }
                }

                var orderedResults = [CleanupScanResult?](repeating: nil, count: categoriesToScan.count)

                for try await (offset, result) in group {
                    orderedResults[offset] = result
                }

                return orderedResults.compactMap { $0 }
            }

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
        guard let cacheResult = scanResults.first(where: { $0.category.id == .userCaches }) else {
            lastError = "Run a scan before clearing caches."
            return
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
        .filter { $0.size > 0 }
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

    /// Everything a `CleanupItem` needs, prefetched by the directory read so the
    /// per-item `resourceValues` lookup is served from the cached values.
    nonisolated private static let itemResourceKeys: Set<URLResourceKey> = [
        .contentModificationDateKey,
        .isDirectoryKey,
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]

    nonisolated private static let sizeResourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]

    nonisolated private static func cleanupItems(in directoryURL: URL) -> [CleanupItem] {
        guard let childURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(itemResourceKeys),
            options: []
        ) else {
            return [cleanupItem(at: directoryURL)]
        }

        return childURLs.map(cleanupItem(at:))
    }

    nonisolated private static func cleanupItem(at url: URL) -> CleanupItem {
        let values = try? url.resourceValues(forKeys: itemResourceKeys)
        let isDirectory = values?.isDirectory == true
        let allocatedSize = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)

        return CleanupItem(
            url: url,
            // Only directories need a recursive walk; a plain file's own allocated
            // size is already the answer.
            size: isDirectory ? directorySize(at: url, seededWith: allocatedSize) : allocatedSize,
            modifiedDate: values?.contentModificationDate,
            isDirectory: isDirectory
        )
    }

    nonisolated private static func directorySize(at url: URL, seededWith allocatedSize: Int64) -> Int64 {
        // Hidden files are counted: caches and trash are full of dotfiles, and
        // skipping them under-reports reclaimable space.
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeResourceKeys),
            options: []
        ) else {
            return allocatedSize
        }

        var totalBytes = allocatedSize

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: sizeResourceKeys) else {
                continue
            }

            if values.isRegularFile == true {
                totalBytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }

        return totalBytes
    }
}
