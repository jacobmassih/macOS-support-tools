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

struct CleanupItem: Identifiable, Codable {
    var id: URL { url }

    let url: URL
    let size: Int64
    let modifiedDate: Date?
    var isDirectory = false

    var systemImage: String {
        isDirectory ? "folder" : "doc"
    }
}

struct CleanupScanResult: Identifiable, Codable {
    var id: CleanupCategoryID { category.id }

    let category: CleanupCategory
    let totalBytes: Int64
    let itemCount: Int
    let items: [CleanupItem]
    let accessError: String?

    let largestItem: CleanupItem?
    let mostRecentModifiedDate: Date?

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

    // Derived values stay out of the serialized format and are rebuilt when
    // decoding, so older payloads and newly scanned results behave alike.
    private enum CodingKeys: String, CodingKey {
        case category, totalBytes, itemCount, items, accessError
    }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            category: try values.decode(CleanupCategory.self, forKey: .category),
            totalBytes: try values.decode(Int64.self, forKey: .totalBytes),
            itemCount: try values.decode(Int.self, forKey: .itemCount),
            items: try values.decode([CleanupItem].self, forKey: .items),
            accessError: try values.decodeIfPresent(String.self, forKey: .accessError)
        )
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
