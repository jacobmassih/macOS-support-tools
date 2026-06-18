import SwiftUI

struct MouseSettingsView: View {
    @Environment(AccessibilityTrustManager.self) private var accessibilityTrustManager
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        SettingsHeader(
            title: "Mouse",
            subtitle: "Tune global mouse behavior."
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

            if !accessibilityTrustManager.accessibilityTrusted {
                Divider()

                Button {
                    accessibilityTrustManager.refresh(prompt: true)
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
