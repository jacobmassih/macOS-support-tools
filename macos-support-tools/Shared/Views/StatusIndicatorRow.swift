import SwiftUI

/// A status line for the settings cards: a tinted icon, a title, an optional
/// detail line explaining the state, and a capsule badge carrying the state
/// itself. Green reads as working, amber as needing attention, so a card built
/// from these rows can be scanned at a glance.
struct StatusIndicatorRow: View {
    let title: String
    let systemImage: String
    let badge: String
    var detail: String?
    let isActive: Bool
    /// Colour used when inactive. Amber by default, since most inactive
    /// states here need the user to act; pass `.secondary` for states that
    /// are merely informational, such as no external mouse being plugged in.
    var inactiveTint: Color = .orange

    private var tint: Color { isActive ? .green : inactiveTint }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            Text(badge)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint.opacity(0.15)))
        }
    }
}

/// Splits a manager's `tapStatus` string — `"Active"` or
/// `"Inactive - <reason>"` — into the badge text and the reason shown beneath
/// the title.
struct TapStatusDisplay {
    let badge: String
    let detail: String?
    let isActive: Bool

    init(_ tapStatus: String) {
        let components = tapStatus.components(separatedBy: " - ")
        badge = components.first ?? tapStatus
        detail = components.count > 1
            ? components.dropFirst().joined(separator: " - ")
            : nil
        isActive = badge == "Active"
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsCard {
            PermissionStatusRow(title: "Accessibility access", isGranted: true)

            Divider()

            TapStatusRow(tapStatus: "Active")
        }

        SettingsCard {
            PermissionStatusRow(title: "Accessibility access", isGranted: false)

            Divider()

            TapStatusRow(tapStatus: "Inactive - Accessibility permission required")
        }
    }
    .padding()
}
