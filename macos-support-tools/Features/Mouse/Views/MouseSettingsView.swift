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
            PermissionStatusRow(
                title: "Accessibility access",
                isGranted: accessibilityManager.isAccessibilityEnabled
            )

            Divider()

            StatusIndicatorRow(
                title: "Connected external mouse",
                systemImage: "computermouse.fill",
                badge: mouseManager.isAnyExternalMouseConnected ? "Connected" : "Not connected",
                isActive: mouseManager.isAnyExternalMouseConnected,
                inactiveTint: .secondary
            )

            Divider()

            TapStatusRow(tapStatus: mouseManager.tapStatus)

            if !accessibilityManager.isAccessibilityEnabled {
                Divider()

                AccessibilityAccessButton()
            }
        }
    }
}
