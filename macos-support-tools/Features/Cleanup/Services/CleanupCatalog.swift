import Foundation

enum CleanupCatalog {
    static func defaultCategories() -> [CleanupCategory] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

        return [
            CleanupCategory(
                id: .userCaches,
                title: "User Caches",
                subtitle: "App cache files in your user Library. Apps may recreate these after cleanup.",
                systemImage: "shippingbox",
                paths: [
                    homeDirectory.appending(path: "Library/Caches", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .temporaryFiles,
                title: "Temporary Files",
                subtitle: "Short-lived files from macOS and apps.",
                systemImage: "clock.arrow.circlepath",
                paths: [
                    URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory),
                    URL(filePath: "/private/tmp", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .xcodeDerivedData,
                title: "Xcode DerivedData",
                subtitle: "Build intermediates that Xcode can regenerate.",
                systemImage: "hammer",
                paths: [
                    homeDirectory.appending(path: "Library/Developer/Xcode/DerivedData", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .logs,
                title: "Logs",
                subtitle: "User diagnostic logs. Recent logs can help troubleshoot apps.",
                systemImage: "doc.text.magnifyingglass",
                paths: [
                    homeDirectory.appending(path: "Library/Logs", directoryHint: .isDirectory)
                ],
                riskLevel: .review
            ),
            CleanupCategory(
                id: .trash,
                title: "Trash",
                subtitle: "Items already moved to Trash. Review before emptying in Finder.",
                systemImage: "trash",
                paths: [
                    homeDirectory.appending(path: ".Trash", directoryHint: .isDirectory)
                ],
                riskLevel: .review
            )
        ]
    }
}
