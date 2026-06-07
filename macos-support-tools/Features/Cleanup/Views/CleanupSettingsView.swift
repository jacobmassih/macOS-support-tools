import SwiftUI

struct CleanupSettingsView: View {
    @Environment(CleanupManager.self) private var cleanupManager

    var body: some View {
        SettingsHeader(
            title: "Disk Cleanup",
            subtitle: "Scan disk cleanup areas, review candidates, and move selected items to Trash."
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
                title: cleanupManager.isScanning ? "Scanning disk cleanup areas" : "No scan results yet",
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
