import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case mouse = "Mouse"
    case keyboard = "Keyboard"
    case cleanup = "Disk Cleanup"
    case citrix = "Citrix"
    case devices = "Devices"
    case app = "App"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .mouse: return "computermouse"
        case .keyboard: return "keyboard"
        case .cleanup: return "sparkle.magnifyingglass"
        case .citrix: return "rectangle.connected.to.line.below"
        case .devices: return "rectangle.stack.badge.plus"
        case .app: return "gearshape"
        }
    }
}

struct SettingsRootView: View {
    @Environment(MouseManager.self) private var mouseManager
    @State private var selectedSection: SettingsSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedSection ?? .overview {
                    case .overview:
                        OverviewSettingsView()
                    case .mouse:
                        MouseSettingsView()
                    case .keyboard:
                        KeyboardSettingsView()
                    case .cleanup:
                        CleanupSettingsView()
                    case .citrix:
                        CitrixSettingsView()
                    case .devices:
                        DeviceSettingsView()
                    case .app:
                        AppSettingsView()
                    }
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(.background)
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}

#Preview {
    let accessibilityManager = AccessibilityManager()

    SettingsRootView()
        .environment(accessibilityManager)
        .environment(KeyboardManager(accessibilityManager: accessibilityManager))
        .environment(MouseManager(accessibilityManager: accessibilityManager))
        .environment(CleanupManager())
        .environment(LaunchAtLogin())
}
