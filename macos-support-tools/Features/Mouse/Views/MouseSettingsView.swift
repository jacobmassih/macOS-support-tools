import SwiftUI

struct MouseSettingsView: View {
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        @Bindable var mouseManager = mouseManager

        SettingsHeader(
            title: "Mouse",
            subtitle: "Tune global mouse behavior."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Natural scroll",
                subtitle: "When disabled, scroll wheel input from an external mouse is inverted.",
                systemImage: "arrow.up.and.down",
                isOn: $mouseManager.naturalScrollEnabled
            )

            Divider()

            SettingToggleRow(
                title: "Mouse button actions",
                subtitle: "Enable custom side-button handling for back, forward, and middle-click actions.",
                systemImage: "button.horizontal",
                isOn: $mouseManager.mouseButtonsEnabled
            )
        }

        SettingsCard {
            LabeledContent("Connected external mouse") {
                Text(mouseManager.isAnyExternalMouseConnected ? "Yes" : "No")
                    .foregroundStyle(mouseManager.isAnyExternalMouseConnected ? .green : .secondary)
            }

            Divider()

            LabeledContent("Tap status") {
                Text(mouseManager.tapStatus)
                    .foregroundStyle(.secondary)
            }

            if !accessibilityManager.isAccessibilityEnabled {
                Divider()

                AccessibilityAccessButton()
            }
        }
    }
}
