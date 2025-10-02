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
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $mouseManager.naturalScrollEnabled) {
                    Label("Natural Scroll", systemImage: "arrow.up.arrow.down")
                        .padding(.trailing, 20) // small gap before switch
                }
                .toggleStyle(.switch)
                .controlSize(.small) 
            }

            Divider().padding(.vertical, 4)

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q")
            }
        }
        .padding(12)
        .frame(width: 260)     // comfortable panel width
        .scaleEffect(0.96)     // optional subtle compacting
    }
}

struct StatusBarManager_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarManager()
            .environmentObject(MouseManager())
    }
}
