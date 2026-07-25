import SwiftUI

/// A row that surfaces whether a permission is currently active, using color
/// (green) and an icon so the state is legible at a glance. When inactive it
/// shows an amber badge to draw attention.
struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        StatusIndicatorRow(
            title: title,
            systemImage: isGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
            badge: isGranted ? "Active" : "Inactive",
            isActive: isGranted
        )
    }
}

/// A row that surfaces whether an event tap is running, matching the
/// permission row so a status card reads as one system.
struct TapStatusRow: View {
    let tapStatus: String

    var body: some View {
        let display = TapStatusDisplay(tapStatus)

        StatusIndicatorRow(
            title: "Tap status",
            systemImage: "dot.radiowaves.left.and.right",
            badge: display.badge,
            detail: display.detail,
            isActive: display.isActive
        )
    }
}
