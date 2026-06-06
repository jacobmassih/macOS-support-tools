import Foundation

struct CleanupFileClient: Sendable {
    var fileExists: @Sendable (URL) -> Bool
    var isDeletable: @Sendable (URL) -> Bool
    var trashItem: @Sendable (URL) throws -> Void

    nonisolated static let live = CleanupFileClient(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        isDeletable: { FileManager.default.isDeletableFile(atPath: $0.path) },
        trashItem: { url in
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    )
}
