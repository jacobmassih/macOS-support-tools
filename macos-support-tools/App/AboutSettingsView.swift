import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        SettingsHeader(
            title: "About",
            subtitle: "View app details, version information, and build metadata."
        )

        SettingsCard(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "app.badge")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppVersionInfo.displayName)
                        .font(.title3.weight(.semibold))

                    Text(AppVersionInfo.fullVersion)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                AboutRow(label: "Name", value: AppVersionInfo.displayName)
                AboutRow(label: "Version", value: AppVersionInfo.version)
                AboutRow(label: "Build", value: AppVersionInfo.build)
            }
        }
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    AboutSettingsView()
}
