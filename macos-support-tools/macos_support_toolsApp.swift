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
    
    var body: some Scene {
        MenuBarExtra("My App", systemImage: "computermouse") {
            MenuBarManager()
                .environment(mouseManager)
        }
        Window("", id: "main") {
            ContentView().environment(mouseManager)
        }
    }
}
