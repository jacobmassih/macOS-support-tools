import SwiftUI

struct KeyboardSettingsView: View {
    @Binding var keyboardBlocked: Bool

    var body: some View {
        SettingsHeader(
            title: "Keyboard",
            subtitle: "Manage global keyboard input controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Block keyboard",
                subtitle: "Temporarily suppress keyboard input while the app is running.",
                systemImage: "keyboard.badge.eye",
                isOn: $keyboardBlocked
            )
        }
    }
}
