import SwiftUI

struct MenuBarManager: View {
    @Environment(AccessibilityManager.self) var accessibilityManager: AccessibilityManager
    @Environment(KeyboardManager.self) var keyboardManager: KeyboardManager
    @Environment(MouseManager.self) var mouseManager: MouseManager
    @Environment(ThermalManager.self) var thermalManager: ThermalManager
    @State private var launchAtLogin = LaunchAtLogin()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var keyboardManager = keyboardManager
        @Bindable var mouseManager = mouseManager
        @Bindable var thermalManager = thermalManager

        VStack(alignment: .leading, spacing: 12) {
            Toggle("Natural Scroll", isOn: $mouseManager.naturalScrollEnabled)
            Toggle("Mouse Buttons", isOn: $mouseManager.mouseButtonsEnabled)
            Toggle("Keyboard Debounce", isOn: $keyboardManager.keyboardDebounceEnabled)
                .disabled(!accessibilityManager.isAccessibilityEnabled)
            Toggle("Block Keyboard", isOn: $keyboardManager.keyboardBlocked)
                .disabled(!accessibilityManager.isAccessibilityEnabled)

            Divider().padding(.vertical, 2)

            Toggle("Show Temperature", isOn: $thermalManager.showTemperatureInMenuBar)

            VStack(alignment: .leading, spacing: 4) {
                Text(ThermalManager.detailValue(label: "CPU", value: thermalManager.reading.cpuCelsius))
                Text(ThermalManager.detailValue(label: "GPU", value: thermalManager.reading.gpuCelsius))
                Text(thermalManager.statusDescription)
                Text("Updated: \(thermalManager.lastUpdatedDescription)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let lastError = thermalManager.reading.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().padding(.vertical, 2)

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))

            Button("Settings") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            Divider().padding(.vertical, 2)

            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}

struct StatusBarManager_Previews: PreviewProvider {
    static var previews: some View {
        let accessibilityManager = AccessibilityManager()

        MenuBarManager()
            .environment(accessibilityManager)
            .environment(KeyboardManager(accessibilityManager: accessibilityManager))
            .environment(MouseManager(accessibilityManager: accessibilityManager))
            .environment(ThermalManager(startsPolling: false))
    }
}
