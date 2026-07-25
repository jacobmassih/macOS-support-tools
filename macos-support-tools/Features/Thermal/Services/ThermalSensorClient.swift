import Foundation
import IOKit

struct ThermalSensorClient {
    var read: @Sendable () async throws -> ThermalReading
}

extension ThermalSensorClient {
    static let live = ThermalSensorClient {
        try await Task.detached(priority: .utility) {
            try SMCThermalSensorReader.shared.read()
        }.value
    }

    static func mock(_ read: @escaping @Sendable () async throws -> ThermalReading) -> ThermalSensorClient {
        ThermalSensorClient(read: read)
    }
}

enum ThermalSensorError: LocalizedError, Equatable {
    case serviceUnavailable
    case connectionFailed(kern_return_t)
    case unsupportedLayout

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Temperature sensors are unavailable on this Mac."
        case .connectionFailed(let code):
            return "Could not connect to temperature sensors. IOKit returned \(code)."
        case .unsupportedLayout:
            return "Temperature sensors could not be read because the SMC request layout is unsupported."
        }
    }
}

enum SMCSensorRole: Equatable {
    case cpu
    case gpu
}

/// Pure decoding for the SMC wire format, deliberately free of IOKit so every branch is unit testable.
enum SMCDecoder {
    /// Intel Macs expose a handful of fixed die/proximity sensors under uppercase keys.
    nonisolated static let intelCPUKeys: Set<String> = ["TC0P", "TC0D", "TC0E", "TC0F", "TCXC", "TCAD"]
    nonisolated static let intelGPUKeys: Set<String> = ["TG0P", "TG0D", "TG0H", "TG1D", "TG1P"]

    /// Apple silicon has no single die sensor. It spreads temperature across many per-core
    /// sensors named `Tp…` (CPU clusters) and `Tg…` (GPU clusters). Those prefixes are
    /// lowercase, so they never collide with the uppercase Intel keys above and both
    /// families can be probed unconditionally.
    nonisolated static func sensorRole(forKey key: String) -> SMCSensorRole? {
        if key.hasPrefix("Tp") {
            return .cpu
        }

        if key.hasPrefix("Tg") {
            return .gpu
        }

        if intelCPUKeys.contains(key) {
            return .cpu
        }

        if intelGPUKeys.contains(key) {
            return .gpu
        }

        return nil
    }

    /// Packs a four character SMC key into the big-endian `UInt32` the kernel expects.
    nonisolated static func key(_ value: String) -> UInt32 {
        value.utf8.prefix(4).reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
    }

    nonisolated static func name(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]

        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    /// The `Tp…`/`Tg…` prefixes also match a few non-thermal keys, and unpopulated sensors
    /// report sentinel values. Anything outside a believable die temperature is discarded.
    nonisolated static func isPlausibleTemperature(_ value: Double) -> Bool {
        value > 5 && value < 130
    }

    nonisolated static func temperature(bytes: [UInt8], dataSize: UInt32, dataType: UInt32) -> Double? {
        switch name(dataType) {
        case "flt " where dataSize >= 4 && bytes.count >= 4:
            // `flt ` payloads are IEEE-754 singles in little-endian byte order.
            var bits = UInt32(bytes[3]) << 24
            bits |= UInt32(bytes[2]) << 16
            bits |= UInt32(bytes[1]) << 8
            bits |= UInt32(bytes[0])
            return Double(Float(bitPattern: bits))
        case "sp78" where dataSize >= 2 && bytes.count >= 2:
            // Signed 8.8 fixed point, big-endian. Reinterpreting the assembled bit pattern
            // keeps the sign bit and avoids overflowing `Int16` for readings above 127C.
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        case "fpe2" where dataSize >= 2 && bytes.count >= 2:
            // Unsigned 14.2 fixed point, big-endian.
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        default:
            return nil
        }
    }

    /// Apple silicon reports one value per core cluster, so a single key is not representative.
    nonisolated static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    nonisolated static func reading(
        cpuSamples: [Double],
        gpuSamples: [Double],
        timestamp: Date = Date()
    ) -> ThermalReading {
        let cpu = average(cpuSamples)
        let gpu = average(gpuSamples)

        guard cpu != nil || gpu != nil else {
            return ThermalReading(
                cpuCelsius: nil,
                gpuCelsius: nil,
                lastUpdated: timestamp,
                status: .unavailable,
                lastError: "No CPU or GPU temperature sensors returned degree values."
            )
        }

        return ThermalReading(
            cpuCelsius: cpu,
            gpuCelsius: gpu,
            lastUpdated: timestamp,
            status: .available,
            lastError: nil
        )
    }
}

private enum SMCMethod: UInt32 {
    case readKey = 2
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case keyFromIndex = 8
    case readKeyInfo = 9
}

struct SMCKeyInfo: Equatable, Sendable {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    /// The kernel struct is 4-byte aligned and 12 bytes long. Without this explicit tail
    /// padding Swift packs the next field of `SMCParamStruct` into the slack after
    /// `dataAttributes`, shifting every following field 4 bytes low.
    var reserved0: UInt8 = 0
    var reserved1: UInt8 = 0
    var reserved2: UInt8 = 0

    nonisolated init() {}

    nonisolated init(dataSize: UInt32, dataType: UInt32, dataAttributes: UInt8 = 0) {
        self.dataSize = dataSize
        self.dataType = dataType
        self.dataAttributes = dataAttributes
    }
}

struct SMCVersion: Equatable, Sendable {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0

    nonisolated init() {}
}

struct SMCPowerLimitData: Equatable, Sendable {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0

    nonisolated init() {}
}

struct SMCParamStruct: Sendable {
    /// Byte size of the kernel's `SMCParamStruct`. Swift makes no C layout guarantee, so this
    /// is asserted before any call rather than assumed: a mismatch silently corrupts every reply.
    nonisolated static let kernelSize = 80

    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPowerLimitData()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )

    nonisolated init() {}

    nonisolated var bytesArray: [UInt8] {
        withUnsafeBytes(of: bytes) { rawBuffer in
            Array(rawBuffer)
        }
    }
}

struct SMCSensor: Equatable, Sendable {
    var key: UInt32
    var role: SMCSensorRole
    var info: SMCKeyInfo
}

/// One SMC request/response round trip. Injected so the key-table walk, sensor classification
/// and sample aggregation can be exercised without an AppleSMC connection.
struct SMCTransport: Sendable {
    var call: @Sendable (SMCParamStruct) -> SMCParamStruct?

    nonisolated init(call: @escaping @Sendable (SMCParamStruct) -> SMCParamStruct?) {
        self.call = call
    }
}

/// Walks the SMC key table, keeps the keys that report a usable temperature, and turns a
/// sweep of those sensors into a `ThermalReading`.
struct SMCSensorScanner {
    private let transport: SMCTransport

    nonisolated init(transport: SMCTransport) {
        self.transport = transport
    }

    nonisolated func reading(sensors: [SMCSensor], timestamp: Date = Date()) -> ThermalReading {
        var cpuSamples: [Double] = []
        var gpuSamples: [Double] = []

        for sensor in sensors {
            guard let value = temperature(for: sensor) else {
                continue
            }

            switch sensor.role {
            case .cpu:
                cpuSamples.append(value)
            case .gpu:
                gpuSamples.append(value)
            }
        }

        return SMCDecoder.reading(cpuSamples: cpuSamples, gpuSamples: gpuSamples, timestamp: timestamp)
    }

    nonisolated func discoverSensors() -> [SMCSensor] {
        guard let count = keyCount() else {
            return []
        }

        var discovered: [SMCSensor] = []

        for index in 0..<count {
            guard let key = key(at: index),
                  let role = SMCDecoder.sensorRole(forKey: SMCDecoder.name(key)),
                  let info = keyInfo(for: key),
                  info.dataSize > 0 else {
                continue
            }

            let sensor = SMCSensor(key: key, role: role, info: info)

            guard temperature(for: sensor) != nil else {
                continue
            }

            discovered.append(sensor)
        }

        return discovered
    }

    nonisolated func keyCount() -> UInt32? {
        let key = SMCDecoder.key("#KEY")

        guard let info = keyInfo(for: key), info.dataSize >= 4 else {
            return nil
        }

        var input = SMCParamStruct()
        input.key = key
        input.keyInfo = info
        input.data8 = SMCCommand.readBytes.rawValue

        guard let output = transport.call(input) else {
            return nil
        }

        let bytes = output.bytesArray
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    nonisolated func key(at index: UInt32) -> UInt32? {
        var input = SMCParamStruct()
        input.data8 = SMCCommand.keyFromIndex.rawValue
        input.data32 = index

        return transport.call(input)?.key
    }

    nonisolated func keyInfo(for key: UInt32) -> SMCKeyInfo? {
        var input = SMCParamStruct()
        input.key = key
        input.data8 = SMCCommand.readKeyInfo.rawValue

        return transport.call(input)?.keyInfo
    }

    nonisolated func temperature(for sensor: SMCSensor) -> Double? {
        var input = SMCParamStruct()
        input.key = sensor.key
        input.keyInfo = sensor.info
        input.data8 = SMCCommand.readBytes.rawValue

        guard let output = transport.call(input),
              let value = SMCDecoder.temperature(
                  bytes: output.bytesArray,
                  dataSize: sensor.info.dataSize,
                  dataType: sensor.info.dataType
              ) else {
            return nil
        }

        return SMCDecoder.isPlausibleTemperature(value) ? value : nil
    }
}

/// Holds the discovered sensor set across polls. Discovery costs a full key-table walk, so it
/// runs once; an empty sweep is deliberately not cached so a transient SMC failure can recover
/// on the next poll instead of pinning the app to "unavailable" forever.
final class SMCSensorCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedSensors: [SMCSensor]?

    nonisolated init() {}

    nonisolated func sensors(discover: () -> [SMCSensor]) -> [SMCSensor] {
        lock.lock()
        defer { lock.unlock() }

        if let cachedSensors {
            return cachedSensors
        }

        let discovered = discover()

        if !discovered.isEmpty {
            cachedSensors = discovered
        }

        return discovered
    }
}

private final class SMCThermalSensorReader: @unchecked Sendable {
    nonisolated static let shared = SMCThermalSensorReader()

    private let cache = SMCSensorCache()

    nonisolated func read() throws -> ThermalReading {
        guard MemoryLayout<SMCParamStruct>.stride == SMCParamStruct.kernelSize else {
            throw ThermalSensorError.unsupportedLayout
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))

        guard service != 0 else {
            throw ThermalSensorError.serviceUnavailable
        }

        defer {
            IOObjectRelease(service)
        }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)

        guard result == KERN_SUCCESS else {
            throw ThermalSensorError.connectionFailed(result)
        }

        defer {
            IOServiceClose(connection)
        }

        let scanner = SMCSensorScanner(transport: Self.transport(connection: connection))
        return scanner.reading(sensors: cache.sensors { scanner.discoverSensors() })
    }

    private nonisolated static func transport(connection: io_connect_t) -> SMCTransport {
        SMCTransport { request in
            var input = request
            var output = SMCParamStruct()
            let inputSize = MemoryLayout<SMCParamStruct>.stride
            var outputSize = MemoryLayout<SMCParamStruct>.stride

            let result = withUnsafePointer(to: &input) { inputPointer in
                withUnsafeMutablePointer(to: &output) { outputPointer in
                    IOConnectCallStructMethod(
                        connection,
                        SMCMethod.readKey.rawValue,
                        inputPointer,
                        inputSize,
                        outputPointer,
                        &outputSize
                    )
                }
            }

            guard result == KERN_SUCCESS, output.result == 0 else {
                return nil
            }

            return output
        }
    }
}
