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
