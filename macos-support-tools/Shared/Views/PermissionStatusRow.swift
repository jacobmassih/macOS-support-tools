import SwiftUI

/// A row that surfaces whether a permission is currently active, using color
/// (green) and an icon so the state is legible at a glance. When inactive it
/// shows an amber badge to draw attention.
struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool

    private var tint: Color { isGranted ? .green : .orange }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            Text(title)
                .font(.headline)

            Spacer(minLength: 16)

            Text(isGranted ? "Active" : "Inactive")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint.opacity(0.15)))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsCard {
            PermissionStatusRow(title: "Accessibility access", isGranted: true)
        }
        SettingsCard {
            PermissionStatusRow(title: "Accessibility access", isGranted: false)
        }
    }
    .padding()
}
