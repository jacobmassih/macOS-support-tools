import SwiftUI

struct CleanupCandidateRow: View {
    let item: CleanupItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: itemSystemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent.isEmpty ? item.url.path(percentEncoded: false) : item.url.lastPathComponent)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteCountFormatter.cleanupString(fromByteCount: item.size))
                    .font(.caption.weight(.semibold))

                if let modifiedDate = item.modifiedDate {
                    Text(modifiedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }

    private var itemSystemImage: String {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: item.url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return "folder"
        }

        return "doc"
    }
}
