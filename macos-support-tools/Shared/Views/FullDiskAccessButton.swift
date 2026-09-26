import SwiftUI

struct FullDiskAccessButton: View {
    var body: some View {
        Button {
            guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
                return
            }
            NSWorkspace.shared.open(settingsURL)
        } label: {
            Label("Review Full Disk Access Settings", systemImage: "lock.open")
        }
    }
}
