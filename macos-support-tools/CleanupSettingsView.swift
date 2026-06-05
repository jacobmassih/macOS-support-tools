import SwiftUI

struct CleanupSettingsView: View {
    @Environment(CleanupManager.self) private var cleanupManager

    var body: some View {
        SettingsHeader(
            title: "Cleanup",
            subtitle: "Scan cleanup areas, review candidates, and move selected items to Trash."
        )

        SettingsCard {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(ByteCountFormatter.cleanupString(fromByteCount: cleanupManager.totalReclaimableBytes))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    Text(cleanupManager.scanResults.isEmpty ? "Run a scan to estimate reclaimable space." : "Estimated reclaimable space across scanned categories.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await cleanupManager.clearAllCaches()
                        }
                    } label: {
                        if cleanupManager.isCleaning {
                            Label("Clearing...", systemImage: "hourglass")
                        } else {
                            Label("Clear All Caches", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(cleanupManager.isScanning || cleanupManager.isCleaning)

                    Button {
                        Task {
                            await cleanupManager.scan()
                        }
                    } label: {
                        if cleanupManager.isScanning {
                            Label("Scanning...", systemImage: "hourglass")
                        } else {
                            Label("Scan Mac", systemImage: "sparkle.magnifyingglass")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(cleanupManager.isScanning || cleanupManager.isCleaning)
                }
            }

            if let lastScanDate = cleanupManager.lastScanDate {
                Divider()

                LabeledContent("Last scan") {
                    Text(lastScanDate.formatted(date: .abbreviated, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = cleanupManager.lastError {
                Divider()

                Label(lastError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let lastCleanupResult = cleanupManager.lastCleanupResult {
                Divider()

                CleanupRunSummary(result: lastCleanupResult)
            }
        }

        if cleanupManager.scanResults.isEmpty {
            EmptyStateView(
                title: cleanupManager.isScanning ? "Scanning cleanup areas" : "No scan results yet",
                subtitle: cleanupManager.isScanning ? "Checking caches, temporary files, Xcode build data, logs, and Trash." : "Start with a scan to find cleanup candidates.",
                systemImage: cleanupManager.isScanning ? "hourglass" : "sparkle.magnifyingglass"
            )
        } else {
            VStack(spacing: 14) {
                ForEach(cleanupManager.scanResults) { result in
                    CleanupResultCard(result: result)
                }
            }
        }
    }
}

private struct CleanupRunSummary: View {
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

private struct CleanupResultCard: View {
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
                DisclosureGroup {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(result.items.prefix(100))) { item in
                                CleanupCandidateRow(item: item)
                            }

                            if result.items.count > 100 {
                                Text("\(result.items.count - 100) more candidate\(result.items.count - 100 == 1 ? "" : "s") not shown.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                    }
                    .frame(maxHeight: 260)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 8)
                } label: {
                    Label("View candidate files", systemImage: "list.bullet.rectangle")
                        .font(.callout.weight(.medium))
                }
            }
        }
    }
}

private struct CleanupCandidateRow: View {
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
