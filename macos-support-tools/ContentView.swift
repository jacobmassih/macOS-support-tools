//
//  ContentView.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mouseManager: MouseManager
    @State private var statusBarManager = StatusBarManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mouse Scroll Manager")
                .font(.title)
            
            HStack {
                Circle()
                    .fill(mouseManager.isAnyExternalMouseConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                
                Text(mouseManager.isAnyExternalMouseConnected ? "External mouse connected" : "No external mouse")
            }
            
            Text("Natural scroll: \(mouseManager.naturalScrollEnabled ? "ON" : "OFF")")
            
            Button("Toggle Scroll Direction") {
                mouseManager.toggleScrollDirection()
            }
        }
        .padding()
        .onAppear {
            statusBarManager.setupStatusBar()
            statusBarManager.mouseManager = mouseManager
        }
        .onChange(of: mouseManager.isAnyExternalMouseConnected) { _ in
            statusBarManager.updateStatus()
        }
    }
}

#Preview {
    ContentView()
}
