import SwiftUI

struct MenuBarManager: View {
    @Environment(MouseManager.self) var mouseManager: MouseManager
    @Environment(CleanupManager.self) var cleanupManager: CleanupManager
    @State private var launchAtLogin = LaunchAtLogin()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var mouseManager = mouseManager

        VStack(alignment: .leading, spacing: 12) {
            Toggle("Natural Scroll", isOn: $mouseManager.naturalScrollEnabled)
            Toggle("Mouse Buttons", isOn: $mouseManager.mouseButtonsEnabled)
            Toggle("Block Keyboard", isOn: $mouseManager.keyboardBlocked)
            Toggle("Citrix Compatibility", isOn: $mouseManager.citrixPassthroughEnabled)

            Divider().padding(.vertical, 2)

            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
                Task {
                    await cleanupManager.scan()
                }
            } label: {
                Label("Scan Cleanup", systemImage: "sparkle.magnifyingglass")
            }
            .disabled(cleanupManager.isScanning)

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
        .frame(width: 230)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}

struct StatusBarManager_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarManager()
            .environment(MouseManager())
            .environment(CleanupManager())
    }
}
