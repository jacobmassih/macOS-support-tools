//
//  StatusBarManager.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import SwiftUI

struct StatusBarManager: View {
    @EnvironmentObject var mouseManager: MouseManager

    var body: some View {
        VStack {
            Toggle(isOn: $mouseManager.naturalScrollEnabled) {
                Text("Natural Scroll")
            }
            .toggleStyle(.switch)
            
            Divider().padding(.vertical, 5)
            
            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
    }
}
