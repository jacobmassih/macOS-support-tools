import Foundation
import Observation

@Observable
final class ThermalManager {
    enum DefaultsKey {
        static let showTemperatureInMenuBar = "ShowTemperatureInMenuBar"
    }

    static let pollingInterval: Duration = .seconds(5)
    static let staleInterval: TimeInterval = 30

    var showTemperatureInMenuBar = false {
        didSet {
            userDefaults.set(showTemperatureInMenuBar, forKey: DefaultsKey.showTemperatureInMenuBar)
            updatePollingState()
        }
    }

    private(set) var reading: ThermalReading = .idle
    private(set) var isRefreshing = false

    var menuBarTitle: String {
        guard showTemperatureInMenuBar else {
            return "Support Tools"
        }

        return Self.menuBarTitle(for: reading)
    }

    var statusDescription: String {
        switch reading.status {
        case .idle:
            return showTemperatureInMenuBar ? "Waiting for temperature reading" : "Temperature display disabled"
        case .available:
            if reading.isStale(staleAfter: Self.staleInterval) {
                return "Temperature reading stale"
            }

            return "Temperature sensors available"
        case .unavailable:
            return "Temperature sensors unavailable"
        case .failed:
            return "Temperature reading failed"
        }
    }

    var lastUpdatedDescription: String {
        guard let lastUpdated = reading.lastUpdated else {
            return "Never"
        }

        return lastUpdated.formatted(date: .omitted, time: .shortened)
    }

    private let sensorClient: ThermalSensorClient
    private let userDefaults: UserDefaults
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    init(
        sensorClient: ThermalSensorClient = .live,
        userDefaults: UserDefaults = .standard,
        startsPolling: Bool = true
    ) {
        self.sensorClient = sensorClient
        self.userDefaults = userDefaults

        userDefaults.register(defaults: [
            DefaultsKey.showTemperatureInMenuBar: false
        ])

        showTemperatureInMenuBar = userDefaults.bool(forKey: DefaultsKey.showTemperatureInMenuBar)

        if startsPolling {
            updatePollingState()
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    @MainActor
    func refresh() async {
        isRefreshing = true

        do {
            reading = try await sensorClient.read()
        } catch {
            let message = error.localizedDescription
            reading = ThermalReading(
                cpuCelsius: nil,
                gpuCelsius: nil,
                lastUpdated: Date(),
                status: .failed(message),
                lastError: message
            )
        }

        isRefreshing = false
    }

    static func menuBarTitle(for reading: ThermalReading, now: Date = Date()) -> String {
        guard !reading.isStale(relativeTo: now, staleAfter: Self.staleInterval) else {
            return "Temp --"
        }

        let parts = [
            formattedTemperature(label: "CPU", value: reading.cpuCelsius),
            formattedTemperature(label: "GPU", value: reading.gpuCelsius)
        ].compactMap { $0 }

        guard !parts.isEmpty else {
            return "Temp --"
        }

        return parts.joined(separator: "  ")
    }

    static func detailValue(label: String, value: Double?) -> String {
        formattedTemperature(label: label, value: value) ?? "\(label) unavailable"
    }

    private static func formattedTemperature(label: String, value: Double?) -> String? {
        guard let value else {
            return nil
        }

        return "\(label) \(Int(value.rounded()))C"
    }

    private func updatePollingState() {
        pollingTask?.cancel()
        pollingTask = nil

        guard showTemperatureInMenuBar else {
            reading = .idle
            return
        }

        pollingTask = Task { [weak self] in
            await self?.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.pollingInterval)
                } catch {
                    return
                }

                await self?.refresh()
            }
        }
    }
}
