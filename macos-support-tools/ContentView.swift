//
//  ContentView.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-26.
//

import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case mouse = "Mouse"
    case cleanup = "Cleanup"
    case citrix = "Citrix"
    case devices = "Devices"
    case app = "App"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .mouse: return "computermouse"
        case .cleanup: return "sparkle.magnifyingglass"
        case .citrix: return "rectangle.connected.to.line.below"
        case .devices: return "rectangle.stack.badge.plus"
        case .app: return "gearshape"
        }
    }
}

struct ContentView: View {
    @Environment(MouseManager.self) private var mouseManager
    @State private var launchAtLogin = LaunchAtLogin()
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
                        OverviewSettingsView(launchAtLogin: launchAtLogin)
                    case .mouse:
                        MouseSettingsView()
                    case .cleanup:
                        CleanupSettingsView()
                    case .citrix:
                        CitrixSettingsView()
                    case .devices:
                        DeviceSettingsView()
                    case .app:
                        AppSettingsView(launchAtLogin: launchAtLogin)
                    }
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .background(.background)
        }
        .environment(mouseManager)
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}

private struct OverviewSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        SettingsHeader(
            title: "Settings",
            subtitle: "Control mouse behavior, Citrix compatibility, connected devices, and app startup."
        )

        SettingsCard(spacing: 0) {
            HStack(spacing: 0) {
                StatusPill(
                    title: "External Mouse",
                    value: mouseManager.isAnyExternalMouseConnected ? "Connected" : "Not Connected",
                    systemImage: "computermouse",
                    tint: mouseManager.isAnyExternalMouseConnected ? .green : .secondary
                )

                VerticalDivider()

                StatusPill(
                    title: "Event Tap",
                    value: mouseManager.tapStatus,
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: mouseManager.tapStatus == "Active" ? .green : .orange
                )

                VerticalDivider()

                StatusPill(
                    title: "Citrix",
                    value: mouseManager.citrixMonitor.isCitrixActive ? "Active" : "Inactive",
                    systemImage: "rectangle.connected.to.line.below",
                    tint: mouseManager.citrixMonitor.isCitrixActive ? .blue : .secondary
                )

                VerticalDivider()

                StatusPill(
                    title: "Launch at Login",
                    value: launchAtLogin.isEnabled ? "Enabled" : "Disabled",
                    systemImage: "power",
                    tint: launchAtLogin.isEnabled ? .green : .secondary
                )
            }
        }

        SettingsCard {
            SettingToggleRow(
                title: "Natural scroll",
                subtitle: "Keep scroll direction consistent with macOS when an external mouse is connected.",
                systemImage: "arrow.up.and.down",
                isOn: mouseBinding(\.naturalScrollEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Mouse buttons",
                subtitle: "Apply configured actions to side mouse buttons.",
                systemImage: "button.horizontal",
                isOn: mouseBinding(\.mouseButtonsEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Citrix compatibility",
                subtitle: "Let Citrix receive side-button events directly when Citrix Viewer is active.",
                systemImage: "rectangle.connected.to.line.below",
                isOn: mouseBinding(\.citrixPassthroughEnabled)
            )
        }
    }

    private func mouseBinding(_ keyPath: ReferenceWritableKeyPath<MouseManager, Bool>) -> Binding<Bool> {
        Binding {
            mouseManager[keyPath: keyPath]
        } set: {
            mouseManager[keyPath: keyPath] = $0
        }
    }
}

private struct MouseSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        SettingsHeader(
            title: "Mouse",
            subtitle: "Tune global mouse behavior and temporary input controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Natural scroll",
                subtitle: "When disabled, scroll wheel input from an external mouse is inverted.",
                systemImage: "arrow.up.and.down",
                isOn: binding(\.naturalScrollEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Mouse button actions",
                subtitle: "Enable custom side-button handling for back, forward, and middle-click actions.",
                systemImage: "button.horizontal",
                isOn: binding(\.mouseButtonsEnabled)
            )

            Divider()

            SettingToggleRow(
                title: "Block keyboard",
                subtitle: "Temporarily suppress keyboard input while the app is running.",
                systemImage: "keyboard.badge.eye",
                isOn: binding(\.keyboardBlocked)
            )
        }

        SettingsCard {
            LabeledContent("Connected external mouse") {
                Text(mouseManager.isAnyExternalMouseConnected ? "Yes" : "No")
                    .foregroundStyle(mouseManager.isAnyExternalMouseConnected ? .green : .secondary)
            }

            Divider()

            LabeledContent("Tap status") {
                Text(mouseManager.tapStatus)
                    .foregroundStyle(.secondary)
            }

            if !mouseManager.accessibilityTrusted {
                Divider()

                Button {
                    mouseManager.refreshAccessibilityTrust(prompt: true)
                } label: {
                    Label("Request Accessibility Access", systemImage: "lock.open")
                }
            }
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<MouseManager, Bool>) -> Binding<Bool> {
        Binding {
            mouseManager[keyPath: keyPath]
        } set: {
            mouseManager[keyPath: keyPath] = $0
        }
    }
}

private struct CitrixSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        SettingsHeader(
            title: "Citrix",
            subtitle: "Control how mouse button handling behaves while Citrix Viewer is active."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Citrix compatibility",
                subtitle: "When enabled, the app leaves side-button events untouched while Citrix Viewer is frontmost.",
                systemImage: "rectangle.connected.to.line.below",
                isOn: Binding {
                    mouseManager.citrixPassthroughEnabled
                } set: {
                    mouseManager.citrixPassthroughEnabled = $0
                }
            )

            Divider()

            LabeledContent("Current Citrix state") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(mouseManager.citrixMonitor.isCitrixActive ? .green : .secondary)
                        .frame(width: 8, height: 8)

                    Text(mouseManager.citrixMonitor.isCitrixActive ? "Active" : "Inactive")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CleanupSettingsView: View {
    @Environment(CleanupManager.self) private var cleanupManager

    var body: some View {
        SettingsHeader(
            title: "Cleanup",
            subtitle: "Scan cleanup areas, review candidates, and move selected items to Trash."
        )

        SettingsCard {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(ByteCountFormatter.cleanupString(fromByteCount: cleanupManager.totalReclaimableBytes))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    Text(cleanupManager.scanResults.isEmpty ? "Run a scan to estimate reclaimable space." : "Estimated reclaimable space across scanned categories.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Button {
                    Task {
                        await cleanupManager.scan()
                    }
                } label: {
                    if cleanupManager.isScanning {
                        Label("Scanning...", systemImage: "hourglass")
                    } else {
                        Label("Scan Mac", systemImage: "sparkle.magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(cleanupManager.isScanning || cleanupManager.isCleaning)
            }

            if let lastScanDate = cleanupManager.lastScanDate {
                Divider()

                LabeledContent("Last scan") {
                    Text(lastScanDate.formatted(date: .abbreviated, time: .standard))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = cleanupManager.lastError {
                Divider()

                Label(lastError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let lastCleanupResult = cleanupManager.lastCleanupResult {
                Divider()

                CleanupRunSummary(result: lastCleanupResult)
            }
        }

        if cleanupManager.scanResults.isEmpty {
            EmptyStateView(
                title: cleanupManager.isScanning ? "Scanning cleanup areas" : "No scan results yet",
                subtitle: cleanupManager.isScanning ? "Checking caches, temporary files, Xcode build data, logs, and Trash." : "Start with a scan to find cleanup candidates.",
                systemImage: cleanupManager.isScanning ? "hourglass" : "sparkle.magnifyingglass"
            )
        } else {
            VStack(spacing: 14) {
                ForEach(cleanupManager.scanResults) { result in
                    CleanupResultCard(result: result)
                }
            }
        }
    }
}

private struct CleanupRunSummary: View {
    let result: CleanupRunResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(summaryText, systemImage: result.skippedItems.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(result.skippedItems.isEmpty ? .green : .orange)

            if !result.skippedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.skippedItems.prefix(3)) { skippedItem in
                        Text("\(skippedItem.item.url.lastPathComponent): \(skippedItem.reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    if result.skippedItems.count > 3 {
                        Text("\(result.skippedItems.count - 3) more skipped item\(result.skippedItems.count - 3 == 1 ? "" : "s").")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var summaryText: String {
        let movedText = "\(result.trashedItems.count) item\(result.trashedItems.count == 1 ? "" : "s") moved to Trash"
        let sizeText = ByteCountFormatter.cleanupString(fromByteCount: result.trashedBytes)

        if result.skippedItems.isEmpty {
            return "\(movedText) (\(sizeText))."
        }

        return "\(movedText) (\(sizeText)); \(result.skippedItems.count) skipped."
    }
}

private struct CleanupResultCard: View {
    @Environment(CleanupManager.self) private var cleanupManager
    let result: CleanupScanResult

    var body: some View {
        SettingsCard(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: result.category.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(result.category.title)
                            .font(.headline)

                        Text(result.category.riskLevel.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundStyle(result.category.riskLevel == .safe ? .green : .orange)
                            .background((result.category.riskLevel == .safe ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    }

                    Text(result.category.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ByteCountFormatter.cleanupString(fromByteCount: result.totalBytes))
                        .font(.title3.weight(.semibold))

                    Text("\(result.itemCount) candidate\(result.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await cleanupManager.clean(items: result.items)
                    }
                } label: {
                    if cleanupManager.isCleaning {
                        Label("Moving...", systemImage: "hourglass")
                    } else {
                        Label("Move to Trash", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(cleanupManager.isScanning || cleanupManager.isCleaning || result.items.isEmpty)
            }

            Divider()

            Text(result.category.riskLevel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if result.items.isEmpty {
                Label("No candidate files found.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(result.items.prefix(100))) { item in
                                CleanupCandidateRow(item: item)
                            }

                            if result.items.count > 100 {
                                Text("\(result.items.count - 100) more candidate\(result.items.count - 100 == 1 ? "" : "s") not shown.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                    }
                    .frame(maxHeight: 260)
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 8)
                } label: {
                    Label("View candidate files", systemImage: "list.bullet.rectangle")
                        .font(.callout.weight(.medium))
                }
            }
        }
    }
}

private struct CleanupCandidateRow: View {
    let item: CleanupItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: itemSystemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent.isEmpty ? item.url.path(percentEncoded: false) : item.url.lastPathComponent)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteCountFormatter.cleanupString(fromByteCount: item.size))
                    .font(.caption.weight(.semibold))

                if let modifiedDate = item.modifiedDate {
                    Text(modifiedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }

    private var itemSystemImage: String {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: item.url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return "folder"
        }

        return "doc"
    }
}

private struct DeviceSettingsView: View {
    @Environment(MouseManager.self) private var mouseManager

    var body: some View {
        SettingsHeader(
            title: "Devices",
            subtitle: "Review connected mice and configure per-device side button behavior."
        )

        if mouseManager.connectedDevices.isEmpty {
            EmptyStateView(
                title: "No mouse connected",
                subtitle: "Connect an external mouse to configure device-specific button actions.",
                systemImage: "computermouse"
            )
        } else {
            VStack(spacing: 14) {
                ForEach(mouseManager.connectedDevices) { device in
                    DeviceCard(device: device)
                }
            }
        }
    }
}

private struct DeviceCard: View {
    @Environment(MouseManager.self) private var mouseManager
    let device: MouseDevice

    var body: some View {
        SettingsCard(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)

                    Text("\(String(format: "%04X", device.vendorID)):\(String(format: "%04X", device.productID))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Connected")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }

            Divider()

            SettingToggleRow(
                title: "Button 4",
                subtitle: "Enable handling for the forward side button.",
                systemImage: "arrow.right.circle",
                isOn: buttonEnabledBinding(.button4)
            )

            Picker("Button 4 action", selection: buttonActionBinding(.button4)) {
                ForEach(MouseButtonAction.allCases, id: \.self) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            .disabled(!currentDeviceValue(for: .button4))

            Divider()

            SettingToggleRow(
                title: "Button 5",
                subtitle: "Enable handling for the back side button.",
                systemImage: "arrow.left.circle",
                isOn: buttonEnabledBinding(.button5)
            )

            Picker("Button 5 action", selection: buttonActionBinding(.button5)) {
                ForEach(MouseButtonAction.allCases, id: \.self) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            .disabled(!currentDeviceValue(for: .button5))
        }
    }

    private func buttonEnabledBinding(_ buttonType: MouseButtonType) -> Binding<Bool> {
        Binding {
            currentDeviceValue(for: buttonType)
        } set: { isEnabled in
            mouseManager.updateButtonSettings(for: device.id, buttonType: buttonType, enabled: isEnabled)
        }
    }

    private func buttonActionBinding(_ buttonType: MouseButtonType) -> Binding<MouseButtonAction> {
        Binding {
            currentActionValue(for: buttonType)
        } set: { action in
            mouseManager.updateButtonAction(for: device.id, buttonType: buttonType, action: action)
        }
    }

    private func currentDeviceValue(for buttonType: MouseButtonType) -> Bool {
        let currentDevice = mouseManager.deviceSettings[device.id] ?? device

        switch buttonType {
        case .left: return currentDevice.leftButtonEnabled
        case .right: return currentDevice.rightButtonEnabled
        case .middle: return currentDevice.middleButtonEnabled
        case .button4: return currentDevice.button4Enabled
        case .button5: return currentDevice.button5Enabled
        }
    }

    private func currentActionValue(for buttonType: MouseButtonType) -> MouseButtonAction {
        let currentDevice = mouseManager.deviceSettings[device.id] ?? device

        switch buttonType {
        case .button4: return currentDevice.button4Action
        case .button5: return currentDevice.button5Action
        default: return .none
        }
    }
}

private struct AppSettingsView: View {
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        SettingsHeader(
            title: "App",
            subtitle: "Manage startup behavior and app-level controls."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Launch at login",
                subtitle: "Start Support Tools automatically when you sign in.",
                systemImage: "power",
                isOn: Binding {
                    launchAtLogin.isEnabled
                } set: {
                    launchAtLogin.setEnabled($0)
                }
            )

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Support Tools", systemImage: "xmark.circle")
            }
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var spacing: CGFloat = 12
    let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct StatusPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
    }
}

private struct VerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 42)
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

#Preview {
    ContentView()
        .environment(MouseManager())
        .environment(CleanupManager())
}

private extension ByteCountFormatter {
    static func cleanupString(fromByteCount byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: byteCount)
    }
}
