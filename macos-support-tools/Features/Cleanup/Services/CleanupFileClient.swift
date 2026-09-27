import Foundation

struct CleanupFileClient: Sendable {
    var fileExists: @Sendable (URL) -> Bool
    var isDeletable: @Sendable (URL) -> Bool
    var contentsOfDirectory: @Sendable (URL) throws -> [URL]
    var trashItem: @Sendable (URL) throws -> Void

    init(
        fileExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        isDeletable: @escaping @Sendable (URL) -> Bool = { FileManager.default.isDeletableFile(atPath: $0.path) },
        contentsOfDirectory: @escaping @Sendable (URL) throws -> [URL] = {
            try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        },
        trashItem: @escaping @Sendable (URL) throws -> Void = { url in
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    ) {
        self.fileExists = fileExists
        self.isDeletable = isDeletable
        self.contentsOfDirectory = contentsOfDirectory
        self.trashItem = trashItem
    }

    nonisolated static let live = CleanupFileClient()
}
