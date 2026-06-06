import SwiftUI

struct CleanupRunSummary: View {
    let result: CleanupRunResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(summaryText, systemImage: result.skippedItems.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(result.skippedItems.isEmpty ? .green : .orange)

            if !result.skippedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.skippedItems.prefix(3)) { skippedItem in
                        Text("\(skippedItem.item.url.lastPathComponent): \(skippedItem.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if result.skippedItems.count > 3 {
                        Text("\(result.skippedItems.count - 3) more skipped item\(result.skippedItems.count - 3 == 1 ? "" : "s").")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var summaryText: String {
        let movedText = "\(result.trashedItems.count) item\(result.trashedItems.count == 1 ? "" : "s") moved to Trash"
        let sizeText = ByteCountFormatter.cleanupString(fromByteCount: result.trashedBytes)

        if result.skippedItems.isEmpty {
            return "\(movedText) (\(sizeText))."
        }

        return "\(movedText) (\(sizeText)); \(result.skippedItems.count) skipped."
    }
}
