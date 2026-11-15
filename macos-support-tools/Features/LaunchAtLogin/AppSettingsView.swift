import SwiftUI

struct AppSettingsView: View {
    @Environment(LaunchAtLogin.self) private var launchAtLogin: LaunchAtLogin

    var body: some View {
        SettingsHeader(
            title: "App",
            subtitle: "Manage startup behavior and app-level controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Launch at login",
                subtitle: "Start Support Tools automatically when you sign in.",
                systemImage: "power",
                isOn: Binding {
                    launchAtLogin.isEnabled
                } set: {
                    launchAtLogin.setEnabled($0)
                }
            )

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Support Tools", systemImage: "xmark.circle")
            }
        }
    }
}
