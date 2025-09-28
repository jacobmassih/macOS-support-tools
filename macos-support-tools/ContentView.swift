//
//  ContentView.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mouseManager: MouseManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mouse Scroll Manager")
                .font(.title)
            
            HStack {
                Circle()
                    .fill(mouseManager.isExternalMouseConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                
                Text(mouseManager.isExternalMouseConnected ? "External mouse connected" : "No external mouse")
            }
            
            Text("Natural scroll: \(mouseManager.naturalScrollEnabled ? "ON" : "OFF")")
            
            Button("Toggle Scroll Direction") {
                mouseManager.toggleScrollDirection()
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
