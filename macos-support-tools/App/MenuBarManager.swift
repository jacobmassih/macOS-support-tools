import SwiftUI

struct MenuBarManager: View {
    @Environment(AccessibilityManager.self) var accessibilityManager: AccessibilityManager
    @Environment(KeyboardManager.self) var keyboardManager: KeyboardManager
    @Environment(MouseManager.self) var mouseManager: MouseManager
    @Environment(MusicLaunchInterceptor.self) var musicLaunchInterceptor: MusicLaunchInterceptor
    @State private var launchAtLogin = LaunchAtLogin()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var keyboardManager = keyboardManager
        @Bindable var mouseManager = mouseManager
        @Bindable var musicLaunchInterceptor = musicLaunchInterceptor

        VStack(alignment: .leading, spacing: 12) {
            Toggle("Natural Scroll", isOn: $mouseManager.naturalScrollEnabled)
            Toggle("Mouse Buttons", isOn: $mouseManager.mouseButtonsEnabled)
            Toggle("Keyboard Debounce", isOn: $keyboardManager.keyboardDebounceEnabled)
                .disabled(!accessibilityManager.isAccessibilityEnabled)
            Toggle("Block Keyboard", isOn: $keyboardManager.keyboardBlocked)
                .disabled(!accessibilityManager.isAccessibilityEnabled)
            Toggle("Music to Spotify", isOn: $musicLaunchInterceptor.isEnabled)

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
        .frame(width: 230)
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
            .environment(MusicLaunchInterceptor())
    }
}
