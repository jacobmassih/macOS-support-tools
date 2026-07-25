import SwiftUI

struct DeviceSettingsView: View {
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

            ForEach(MouseButtonType.allCases, id: \.self) { buttonType in
                Divider()

                SettingToggleRow(
                    title: buttonType.title,
                    subtitle: buttonType.subtitle,
                    systemImage: buttonType.systemImage,
                    isOn: buttonEnabledBinding(buttonType)
                )

                Picker("\(buttonType.title) action", selection: buttonActionBinding(buttonType)) {
                    ForEach(MouseButtonAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!currentDeviceValue(for: buttonType))
            }
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
        case .button4: return currentDevice.button4Enabled
        case .button5: return currentDevice.button5Enabled
        }
    }

    private func currentActionValue(for buttonType: MouseButtonType) -> MouseButtonAction {
        let currentDevice = mouseManager.deviceSettings[device.id] ?? device

        switch buttonType {
        case .button4: return currentDevice.button4Action
        case .button5: return currentDevice.button5Action
        }
    }
}

private extension MouseButtonType {
    var title: String {
        switch self {
        case .button4: return "Button 4"
        case .button5: return "Button 5"
        }
    }

    var subtitle: String {
        switch self {
        case .button4: return "Enable handling for the forward side button."
        case .button5: return "Enable handling for the back side button."
        }
    }

    var systemImage: String {
        switch self {
        case .button4: return "arrow.right.circle"
        case .button5: return "arrow.left.circle"
        }
    }
}
