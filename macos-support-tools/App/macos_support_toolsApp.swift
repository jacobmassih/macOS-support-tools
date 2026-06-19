import SwiftUI

@main
struct macos_support_toolsApp: App {
    @State private var accessibilityTrustManager: AccessibilityTrustManager
    @State private var keyboardManager: KeyboardManager
    @State private var mouseManager: MouseManager
    @State private var cleanupManager = CleanupManager()

    init() {
        let accessibilityTrustManager = AccessibilityTrustManager()
        let keyboardManager = KeyboardManager(accessibilityTrustManager: accessibilityTrustManager)
        let mouseManager = MouseManager(accessibilityTrustManager: accessibilityTrustManager)

        accessibilityTrustManager.refresh()

        _accessibilityTrustManager = State(initialValue: accessibilityTrustManager)
        _keyboardManager = State(initialValue: keyboardManager)
        _mouseManager = State(initialValue: mouseManager)
    }

    var body: some Scene {
        MenuBarExtra("Support Tools", systemImage: "wrench.and.screwdriver") {
            MenuBarManager()
                .environment(accessibilityTrustManager)
                .environment(keyboardManager)
                .environment(mouseManager)
        }
        Window("Settings", id: "main") {
            SettingsRootView()
                .environment(accessibilityTrustManager)
                .environment(keyboardManager)
                .environment(mouseManager)
                .environment(cleanupManager)
        }
        .windowResizability(.contentSize)
    }
}
