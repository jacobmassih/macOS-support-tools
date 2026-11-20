import Foundation

enum ThermalStatus: Equatable {
    case idle
    case available
    case unavailable
    case failed(String)
}

struct ThermalReading: Equatable {
    var cpuCelsius: Double?
    var gpuCelsius: Double?
    var lastUpdated: Date?
    var status: ThermalStatus
    var lastError: String?

    static let idle = ThermalReading(
        cpuCelsius: nil,
        gpuCelsius: nil,
        lastUpdated: nil,
        status: .idle,
        lastError: nil
    )

    var hasAnyTemperature: Bool {
        cpuCelsius != nil || gpuCelsius != nil
    }

    func isStale(relativeTo date: Date = Date(), staleAfter interval: TimeInterval) -> Bool {
        guard hasAnyTemperature, let lastUpdated else {
            return false
        }

        return date.timeIntervalSince(lastUpdated) > interval
    }
}
