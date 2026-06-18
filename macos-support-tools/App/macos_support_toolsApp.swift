import SwiftUI

@main
struct macos_support_toolsApp: App {
    @State private var mouseManager = MouseManager(startsSystemServices: !ProcessInfo.processInfo.isRunningTests)
    @State private var cleanupManager = CleanupManager()

    var body: some Scene {
        MenuBarExtra("Support Tools", systemImage: "wrench.and.screwdriver") {
            MenuBarManager()
                .environment(mouseManager)
        }
        Window("Settings", id: "main") {
            SettingsRootView()
                .environment(mouseManager)
                .environment(cleanupManager)
        }
        .windowResizability(.contentSize)
    }
}

private extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
