//
//  StatusBarManager.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import SwiftUI

struct MenuBarManager: View {
    @Environment(MouseManager.self) var mouseManager: MouseManager
    @State private var launchAtLogin = LaunchAtLogin()
    @Environment(\.openWindow) private var openWindow

    
    var body: some View {
        @Bindable var mouseManager = mouseManager
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Natural Scroll", isOn: $mouseManager.naturalScrollEnabled)
            Toggle("Mouse Buttons", isOn: $mouseManager.mouseButtonsEnabled)
            
            Divider().padding(.vertical, 2)
            
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            
            Button("Settings") {
                // NSApp.activate(ignoringOtherApps: true)
                // openWindow(id: "main")
            }
            
            Divider().padding(.vertical, 2)
            
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 200)     // comfortable panel width
        .scaleEffect(0.96)     // optional subtle compacting
    }
}

struct StatusBarManager_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarManager()
            .environment(MouseManager())
    }
}
