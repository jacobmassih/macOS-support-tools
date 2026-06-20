import SwiftUI

struct KeyboardSettingsView: View {
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(KeyboardManager.self) private var keyboardManager

    var body: some View {
        @Bindable var keyboardManager = keyboardManager

        SettingsHeader(
            title: "Keyboard",
            subtitle: "Manage global keyboard input controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Block keyboard",
                subtitle: "Temporarily suppress keyboard input while the app is running.",
                systemImage: "keyboard.badge.eye",
                isOn: $keyboardManager.keyboardBlocked
            )
            .disabled(!accessibilityManager.isAccessibilityEnabled)
        }

        if !accessibilityManager.isAccessibilityEnabled {
            SettingsCard {
                Button {
                    accessibilityManager.refresh(prompt: true)
                } label: {
                    Label("Request Accessibility Access", systemImage: "lock.open")
                }
            }
        }
    }
}
