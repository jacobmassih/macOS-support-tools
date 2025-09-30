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
                        .padding(.trailing, 50)
            }
            .toggleStyle(.switch)
            
        }
        .padding(.all, 10)
    }
}
