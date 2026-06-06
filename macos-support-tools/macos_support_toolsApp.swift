//
//  macos_support_toolsApp.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-26.
//

import SwiftUI

@main
struct macos_support_toolsApp: App {
    @State private var mouseManager = MouseManager()
    @State private var cleanupManager = CleanupManager()

    var body: some Scene {
        MenuBarExtra("Support Tools", systemImage: "computermouse") {
            MenuBarManager()
                .environment(mouseManager)
        }
        Window("Settings", id: "main") {
            ContentView()
                .environment(mouseManager)
                .environment(cleanupManager)
        }
        .windowResizability(.contentSize)
    }
}
