import Foundation

enum CleanupCategoryID: String, CaseIterable, Identifiable, Codable {
    case userCaches
    case temporaryFiles
    case xcodeDerivedData
    case logs
    case trash

    var id: String { rawValue }
}

enum CleanupRiskLevel: String, Codable {
    case safe = "Safe"
    case review = "Review"

    var description: String {
        switch self {
        case .safe:
            return "Usually safe to remove and commonly recreated by apps."
        case .review:
            return "Worth reviewing before cleanup because contents can be useful."
        }
    }
}

struct CleanupCategory: Identifiable, Codable {
    let id: CleanupCategoryID
    let title: String
    let subtitle: String
    let systemImage: String
    let paths: [URL]
    let riskLevel: CleanupRiskLevel
}

struct TrashFileIdentity: Codable, Equatable {
    let device: dev_t
    let inode: ino_t
    let generation: UInt32
    let birthSeconds: Int
    let birthNanoseconds: Int

    nonisolated init?(at url: URL) {
        var info = stat()
        guard url.withUnsafeFileSystemRepresentation({ lstat($0, &info) }) == 0 else { return nil }
        device = info.st_dev
        inode = info.st_ino
        generation = info.st_gen
        birthSeconds = info.st_birthtimespec.tv_sec
        birthNanoseconds = info.st_birthtimespec.tv_nsec
    }
}

struct CleanupItem: Identifiable, Codable {
    var id: URL { url }

    let url: URL
    let size: Int64
    let modifiedDate: Date?
    var trashIdentity: TrashFileIdentity? = nil
    var isDirectory = false

    var systemImage: String {
        isDirectory ? "folder" : "doc"
    }
}

struct CleanupScanResult: Identifiable {
    var id: CleanupCategoryID { category.id }

    let category: CleanupCategory
    let totalBytes: Int64
    let itemCount: Int
    let items: [CleanupItem]
    let accessError: String?

    let largestItem: CleanupItem?
    let mostRecentModifiedDate: Date?

    var isUnavailable: Bool {
        accessError != nil && items.isEmpty
    }

    nonisolated init(
        category: CleanupCategory,
        totalBytes: Int64,
        itemCount: Int,
        items: [CleanupItem],
        accessError: String?
    ) {
        self.category = category
        self.totalBytes = totalBytes
        self.itemCount = itemCount
        self.items = items
        self.accessError = accessError
        largestItem = items.max { $0.size < $1.size }
        mostRecentModifiedDate = items.lazy.compactMap(\.modifiedDate).max()
    }
}

struct CleanupSkippedItem: Identifiable, Codable {
    var id: URL { item.url }

    let item: CleanupItem
    let reason: String
}

struct CleanupRunResult: Codable {
    let trashedItems: [CleanupItem]
    let skippedItems: [CleanupSkippedItem]

    var permanentlyDeleted: Bool? = nil

    var trashedBytes: Int64 {
        trashedItems.reduce(0) { $0 + $1.size }
    }

    var skippedBytes: Int64 {
        skippedItems.reduce(0) { $0 + $1.item.size }
    }

    var didTrashAnyItems: Bool {
        !trashedItems.isEmpty
    }
}
