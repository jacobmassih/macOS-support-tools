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
}

struct CleanupScanResult: Identifiable, Codable {
    var id: CleanupCategoryID { category.id }

    let category: CleanupCategory
    let totalBytes: Int64
    let itemCount: Int
    let items: [CleanupItem]
}
