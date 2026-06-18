import SwiftUI

struct MouseSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        SettingsHeader(
            title: "Mouse",
            subtitle: "Tune global mouse behavior and temporary input controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Natural scroll",
                subtitle: "When disabled, scroll wheel input from an external mouse is inverted.",
                systemImage: "arrow.up.and.down",
                isOn: binding(\.naturalScrollEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Mouse button actions",
                subtitle: "Enable custom side-button handling for back, forward, and middle-click actions.",
                systemImage: "button.horizontal",
                isOn: binding(\.mouseButtonsEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Block keyboard",
                subtitle: "Temporarily suppress keyboard input while the app is running.",
                systemImage: "keyboard.badge.eye",
                isOn: binding(\.keyboardBlocked)
            )

            Divider()

            SettingToggleRow(
                title: "Key chatter filter",
                subtitle: "Drop duplicate key presses that arrive within the debounce window.",
                systemImage: "keyboard.chevron.compact.down",
                isOn: binding(\.keyboardChatterFilterEnabled)
            )

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Debounce window") {
                    Text("\(Int(mouseManager.keyboardChatterFilterDelayMilliseconds)) ms")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding {
                        mouseManager.keyboardChatterFilterDelayMilliseconds
                    } set: {
                        mouseManager.keyboardChatterFilterDelayMilliseconds = $0
                    },
                    in: 5...100,
                    step: 5
                )
                .disabled(!mouseManager.keyboardChatterFilterEnabled)
            }
            .padding(.leading, 42)
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

            if !mouseManager.accessibilityTrusted {
                Divider()

                Button {
                    mouseManager.refreshAccessibilityTrust(prompt: true)
                } label: {
                    Label("Request Accessibility Access", systemImage: "lock.open")
                }
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<MouseManager, Bool>) -> Binding<Bool> {
        Binding {
            mouseManager[keyPath: keyPath]
        } set: {
            mouseManager[keyPath: keyPath] = $0
        }
    }
}
