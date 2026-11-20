import SwiftUI

struct ThermalSettingsView: View {
    @Environment(ThermalManager.self) private var thermalManager

    var body: some View {
        @Bindable var thermalManager = thermalManager

        SettingsHeader(
            title: "Temperature",
            subtitle: "Show best-effort CPU and GPU temperatures in the menu bar."
        )

        SettingsCard {
            SettingToggleRow(
                title: "Show CPU/GPU temperature in menu bar",
                subtitle: "Display live temperature readings when native sensors are available.",
                systemImage: "thermometer.medium",
                isOn: $thermalManager.showTemperatureInMenuBar
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(ThermalManager.detailValue(label: "CPU", value: thermalManager.reading.cpuCelsius), systemImage: "cpu")
                Label(ThermalManager.detailValue(label: "GPU", value: thermalManager.reading.gpuCelsius), systemImage: "display")
                Label("Last updated: \(thermalManager.lastUpdatedDescription)", systemImage: "clock")

                if let lastError = thermalManager.reading.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
