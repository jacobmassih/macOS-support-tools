import Foundation

extension ByteCountFormatter {
    @MainActor private static let cleanupFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    @MainActor static func cleanupString(fromByteCount byteCount: Int64) -> String {
        cleanupFormatter.string(fromByteCount: byteCount)
    }
}
