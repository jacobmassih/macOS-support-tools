import SwiftUI

extension View {
    /// Applies the shared card surface: a rounded material background with a
    /// hairline border. Used by `SettingsCard` and `EmptyStateView` so the two
    /// stay visually identical while keeping their own padding and alignment.
    func cardChrome(cornerRadius: CGFloat = 8) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}
