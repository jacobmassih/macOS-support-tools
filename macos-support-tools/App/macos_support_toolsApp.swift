import SwiftUI

@main
struct macos_support_toolsApp: App {
    @State private var accessibilityManager: AccessibilityManager
    @State private var keyboardManager: KeyboardManager
    @State private var mouseManager: MouseManager
    @State private var thermalManager: ThermalManager
    @State private var cleanupManager = CleanupManager()

    init() {
        let accessibilityManager = AccessibilityManager()
        let keyboardManager = KeyboardManager(accessibilityManager: accessibilityManager)
        let mouseManager = MouseManager(accessibilityManager: accessibilityManager)
        let thermalManager = ThermalManager()
        accessibilityManager.refresh()
        keyboardManager.startSystemServices()
        mouseManager.startSystemServices()

        _accessibilityManager = State(initialValue: accessibilityManager)
        _keyboardManager = State(initialValue: keyboardManager)
        _mouseManager = State(initialValue: mouseManager)
        _thermalManager = State(initialValue: thermalManager)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarManager()
                .environment(accessibilityManager)
                .environment(keyboardManager)
                .environment(mouseManager)
                .environment(thermalManager)
        } label: {
            Label(
                thermalManager.menuBarTitle,
                systemImage: thermalManager.showTemperatureInMenuBar ? "thermometer.medium" : "wrench.and.screwdriver"
            )
        }
        Window("Settings", id: "main") {
            SettingsRootView()
                .environment(accessibilityManager)
                .environment(keyboardManager)
                .environment(mouseManager)
                .environment(thermalManager)
                .environment(cleanupManager)
        }
        .windowResizability(.contentSize)
    }
}
