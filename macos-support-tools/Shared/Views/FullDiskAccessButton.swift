import AppKit
import SwiftUI

/// Full Disk Access has no programmatic prompt the way Accessibility does, so
/// the best an app can do is deep-link into the relevant System Settings pane.
struct FullDiskAccessButton: View {
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )

    var body: some View {
        Button {
            guard let settingsURL = Self.settingsURL else { return }
            NSWorkspace.shared.open(settingsURL)
        } label: {
            Label("Open System Settings", systemImage: "lock.open")
        }
    }
}
