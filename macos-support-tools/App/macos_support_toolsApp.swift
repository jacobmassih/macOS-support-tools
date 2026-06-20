import SwiftUI

@main
struct macos_support_toolsApp: App {
    @State private var accessibilityManager: AccessibilityManager
    @State private var keyboardManager: KeyboardManager
    @State private var mouseManager: MouseManager
    @State private var cleanupManager = CleanupManager()

    init() {
        let accessibilityManager = AccessibilityManager()
        let keyboardManager = KeyboardManager(accessibilityManager: accessibilityManager)
        let mouseManager = MouseManager(accessibilityManager: accessibilityManager)
        accessibilityManager.refresh()

        _accessibilityManager = State(initialValue: accessibilityManager)
        _keyboardManager = State(initialValue: keyboardManager)
        _mouseManager = State(initialValue: mouseManager)
    }

    var body: some Scene {
        MenuBarExtra("Support Tools", systemImage: "wrench.and.screwdriver") {
            MenuBarManager()
                .environment(accessibilityManager)
                .environment(keyboardManager)
                .environment(mouseManager)
        }
        Window("Settings", id: "main") {
            SettingsRootView()
                .environment(accessibilityManager)
                .environment(keyboardManager)
                .environment(mouseManager)
                .environment(cleanupManager)
        }
        .windowResizability(.contentSize)
    }
}
