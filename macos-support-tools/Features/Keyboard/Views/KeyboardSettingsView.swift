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

            Divider()

            SettingToggleRow(
                title: "Keyboard debounce",
                subtitle: "Drop duplicate key presses that arrive within the debounce window.",
                systemImage: "keyboard.chevron.compact.down",
                isOn: $keyboardManager.keyboardDebounceEnabled
            )
            .disabled(!accessibilityManager.isAccessibilityEnabled)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Debounce window") {
                    Text("\(Int(keyboardManager.keyboardDebounceDelayMilliseconds)) ms")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $keyboardManager.keyboardDebounceDelayMilliseconds,
                    in: 5...100,
                    step: 5
                )
                .disabled(!accessibilityManager.isAccessibilityEnabled || !keyboardManager.keyboardDebounceEnabled)
            }
            .padding(.leading, 42)
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
