import SwiftUI

struct MediaSettingsView: View {
    @Environment(MusicLaunchInterceptor.self) private var interceptor

    var body: some View {
        SettingsHeader(
            title: "Media",
            subtitle: "Open Spotify whenever Apple Music launches, including when you open Music yourself."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Redirect Apple Music to Spotify",
                subtitle: "When enabled, any launch of Apple Music (for example when you press play on Bluetooth earphones and nothing is playing) is closed and Spotify is opened instead. No extra permissions are required.",
                systemImage: "music.note",
                isOn: Binding {
                    interceptor.isEnabled
                } set: {
                    interceptor.isEnabled = $0
                }
            )

            Divider()

            StatusPill(
                title: "Spotify",
                value: interceptor.isSpotifyInstalled ? "Installed" : "Not installed",
                systemImage: interceptor.isSpotifyInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: interceptor.isSpotifyInstalled ? .green : .orange
            )

            if !interceptor.isSpotifyInstalled {
                Text("Spotify was not found. Apple Music launches are left alone until Spotify is installed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            interceptor.refreshSpotifyInstalled()
        }
    }
}

#Preview {
    MediaSettingsView()
        .environment(MusicLaunchInterceptor())
        .padding()
}
