import SwiftUI

struct FullDiskAccessButton: View {
    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        } label: {
            Label("Grant Full Disk Access", systemImage: "lock.open")
        }
    }
}
