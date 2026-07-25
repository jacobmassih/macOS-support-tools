import SwiftUI

struct OverviewSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        @Bindable var mouseManager = mouseManager

        SettingsHeader(
            title: "Settings",
            subtitle: "Control mouse behavior, Citrix compatibility, connected devices, and app startup."
        )

        SettingsCard(spacing: 0) {
            HStack(spacing: 0) {
                StatusPill(
                    title: "External Mouse",
                    value: mouseManager.isAnyExternalMouseConnected ? "Connected" : "Not Connected",
                    systemImage: "computermouse",
                    tint: mouseManager.isAnyExternalMouseConnected ? .green : .secondary
                )

                VerticalDivider()

                StatusPill(
                    title: "Event Tap",
                    value: mouseManager.tapStatus,
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: mouseManager.tapStatus == "Active" ? .green : .orange
                )

                VerticalDivider()

                StatusPill(
                    title: "Citrix",
                    value: mouseManager.citrixMonitor.isCitrixActive ? "Active" : "Inactive",
                    systemImage: "rectangle.connected.to.line.below",
                    tint: mouseManager.citrixMonitor.isCitrixActive ? .blue : .secondary
                )

                VerticalDivider()

                StatusPill(
                    title: "Launch at Login",
                    value: launchAtLogin.isEnabled ? "Enabled" : "Disabled",
                    systemImage: "power",
                    tint: launchAtLogin.isEnabled ? .green : .secondary
                )
            }
        }

        SettingsCard {
            SettingToggleRow(
                title: "Natural scroll",
                subtitle: "Keep scroll direction consistent with macOS when an external mouse is connected.",
                systemImage: "arrow.up.and.down",
                isOn: $mouseManager.naturalScrollEnabled
            )

            Divider()

            SettingToggleRow(
                title: "Mouse buttons",
                subtitle: "Apply configured actions to side mouse buttons.",
                systemImage: "button.horizontal",
                isOn: $mouseManager.mouseButtonsEnabled
            )

            Divider()

            SettingToggleRow(
                title: "Citrix compatibility",
                subtitle: "Let Citrix receive side-button events directly when Citrix Viewer is active.",
                systemImage: "rectangle.connected.to.line.below",
                isOn: $mouseManager.citrixPassthroughEnabled
            )
        }
    }
}
