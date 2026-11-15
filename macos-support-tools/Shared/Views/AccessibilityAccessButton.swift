import SwiftUI

struct AccessibilityAccessButton: View {
    @Environment(AccessibilityManager.self) private var accessibilityManager

    var body: some View {
        Button {
            accessibilityManager.refresh(prompt: true)
        } label: {
            Label("Request Accessibility Access", systemImage: "lock.open")
        }
    }
}
