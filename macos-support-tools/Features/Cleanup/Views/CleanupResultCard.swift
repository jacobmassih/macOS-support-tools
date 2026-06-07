import SwiftUI

struct CleanupResultCard: View {
    @Environment(CleanupManager.self) private var cleanupManager
    let result: CleanupScanResult

    var body: some View {
        SettingsCard(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: result.category.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(result.category.title)
                            .font(.headline)

                        Text(result.category.riskLevel.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(result.category.riskLevel == .safe ? .green : .orange)
                            .background((result.category.riskLevel == .safe ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    }

                    Text(result.category.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ByteCountFormatter.cleanupString(fromByteCount: result.totalBytes))
                        .font(.title3.weight(.semibold))

                    Text("\(result.itemCount) candidate\(result.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await cleanupManager.clean(items: result.items)
                    }
                } label: {
                    if cleanupManager.isCleaning {
                        Label("Moving...", systemImage: "hourglass")
                    } else {
                        Label("Move to Trash", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(cleanupManager.isScanning || cleanupManager.isCleaning || result.items.isEmpty)
            }

            Divider()

            Text(result.category.riskLevel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if result.items.isEmpty {
                Label("No candidate files found.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                CleanupPreviewDetails(result: result)
            }
        }
    }
}

private struct CleanupPreviewDetails: View {
    let result: CleanupScanResult
    private let candidatePreviewLimit = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                CleanupPreviewMetric(
                    title: "Largest",
                    value: largestItemText,
                    systemImage: "arrow.up.forward.circle"
                )

                CleanupPreviewMetric(
                    title: "Recent",
                    value: recentDateText,
                    systemImage: "calendar"
                )

                CleanupPreviewMetric(
                    title: "Locations",
                    value: "\(result.category.paths.count)",
                    systemImage: "folder"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Candidate files")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(result.items.prefix(candidatePreviewLimit)) { item in
                            CleanupCandidateRow(item: item)
                        }

                        if remainingCandidateCount > 0 {
                            Text("\(remainingCandidateCount) more candidate\(remainingCandidateCount == 1 ? "" : "s") not shown.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .frame(maxHeight: 260)
            }
            .padding(10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.category.paths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)

                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 12)

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([path])
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderless)
                            .help("Show in Finder")
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Label("Scanned locations", systemImage: "folder")
                    .font(.caption.weight(.medium))
            }
        }
    }

    private var remainingCandidateCount: Int {
        max(result.items.count - candidatePreviewLimit, 0)
    }

    private var largestItemText: String {
        guard let largestItem = result.largestItem else {
            return "None"
        }

        return ByteCountFormatter.cleanupString(fromByteCount: largestItem.size)
    }

    private var recentDateText: String {
        guard let mostRecentModifiedDate = result.mostRecentModifiedDate else {
            return "Unknown"
        }

        return mostRecentModifiedDate.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct CleanupPreviewMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
