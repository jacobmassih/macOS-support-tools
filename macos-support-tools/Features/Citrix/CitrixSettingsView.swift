import SwiftUI

struct CitrixSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        @Bindable var mouseManager = mouseManager

        SettingsHeader(
            title: "Citrix",
            subtitle: "Control how mouse button handling behaves while Citrix Viewer is active."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Citrix compatibility",
                subtitle: "When enabled, the app leaves side-button events untouched while Citrix Viewer is frontmost.",
                systemImage: "rectangle.connected.to.line.below",
                isOn: $mouseManager.citrixPassthroughEnabled
            )

            Divider()

            LabeledContent("Current Citrix state") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(mouseManager.citrixMonitor.isCitrixActive ? .green : .secondary)
                        .frame(width: 8, height: 8)

                    Text(mouseManager.citrixMonitor.isCitrixActive ? "Active" : "Inactive")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
