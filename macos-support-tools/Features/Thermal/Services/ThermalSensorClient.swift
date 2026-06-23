import Foundation
import IOKit

struct ThermalSensorClient {
    var read: @Sendable () async throws -> ThermalReading
}

extension ThermalSensorClient {
    static let live = ThermalSensorClient {
        try await Task.detached(priority: .utility) {
            try SMCThermalSensorReader().read()
        }.value
    }

    static func mock(_ read: @escaping @Sendable () async throws -> ThermalReading) -> ThermalSensorClient {
        ThermalSensorClient(read: read)
    }
}

enum ThermalSensorError: LocalizedError, Equatable {
    case serviceUnavailable
    case connectionFailed(kern_return_t)

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Temperature sensors are unavailable on this Mac."
        case .connectionFailed(let code):
            return "Could not connect to temperature sensors. IOKit returned \(code)."
        }
    }
}

private struct SMCThermalSensorReader {
    nonisolated init() {}

    nonisolated func read() throws -> ThermalReading {
        try readSensors()
    }

    private nonisolated func readSensors() throws -> ThermalReading {
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

        let cpu = readFirstAvailableTemperature(
            keys: ["TC0P", "TC0E", "TC0F", "TC0D", "TCXC"],
            connection: connection
        )
        let gpu = readFirstAvailableTemperature(
            keys: ["TG0P", "TG0D", "TG0H", "TG1D", "TG1P"],
            connection: connection
        )

        guard cpu != nil || gpu != nil else {
            return ThermalReading(
                cpuCelsius: nil,
                gpuCelsius: nil,
                lastUpdated: Date(),
                status: .unavailable,
                lastError: "No CPU or GPU temperature sensors returned degree values."
            )
        }

        return ThermalReading(
            cpuCelsius: cpu,
            gpuCelsius: gpu,
            lastUpdated: Date(),
            status: .available,
            lastError: nil
        )
    }

    private nonisolated func readFirstAvailableTemperature(keys: [String], connection: io_connect_t) -> Double? {
        for key in keys {
            if let temperature = readTemperature(key: key, connection: connection) {
                return temperature
            }
        }

        return nil
    }

    private nonisolated func readTemperature(key: String, connection: io_connect_t) -> Double? {
        guard var keyInfo = readKeyInfo(key: key, connection: connection), keyInfo.dataSize > 0 else {
            return nil
        }

        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.key = smcKey(key)
        input.keyInfo = keyInfo
        input.data8 = SMCCommand.readBytes.rawValue

        guard callSMC(connection: connection, input: &input, output: &output) else {
            return nil
        }

        keyInfo = output.keyInfo.dataSize > 0 ? output.keyInfo : keyInfo
        return temperatureValue(from: output, dataSize: keyInfo.dataSize, dataType: keyInfo.dataType)
    }

    private nonisolated func readKeyInfo(key: String, connection: io_connect_t) -> SMCKeyInfo? {
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.key = smcKey(key)
        input.data8 = SMCCommand.readKeyInfo.rawValue

        guard callSMC(connection: connection, input: &input, output: &output) else {
            return nil
        }

        return output.keyInfo
    }

    private nonisolated func callSMC(connection: io_connect_t, input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
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

        return result == KERN_SUCCESS && output.result == 0
    }

    private nonisolated func temperatureValue(from output: SMCParamStruct, dataSize: UInt32, dataType: UInt32) -> Double? {
        let bytes = output.bytesArray
        let type = smcType(dataType)

        switch type {
        case "sp78" where dataSize >= 2:
            return Double(Int16(bytes[0]) << 8 | Int16(bytes[1])) / 256.0
        case "flt " where dataSize >= 4:
            var floatBits = UInt32(bytes[0]) << 24
            floatBits |= UInt32(bytes[1]) << 16
            floatBits |= UInt32(bytes[2]) << 8
            floatBits |= UInt32(bytes[3])
            return Double(Float(bitPattern: floatBits))
        case "fpe2" where dataSize >= 2:
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        default:
            return nil
        }
    }

    private nonisolated func smcKey(_ value: String) -> UInt32 {
        value.utf8.prefix(4).reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
    }

    private nonisolated func smcType(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]

        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

private enum SMCMethod: UInt32 {
    case readKey = 2
}

private enum SMCCommand: UInt8 {
    case readKeyInfo = 9
    case readBytes = 5
}

private struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0

    nonisolated init(dataSize: UInt32 = 0, dataType: UInt32 = 0, dataAttributes: UInt8 = 0) {
        self.dataSize = dataSize
        self.dataType = dataType
        self.dataAttributes = dataAttributes
    }
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0

    nonisolated init(
        major: UInt8 = 0,
        minor: UInt8 = 0,
        build: UInt8 = 0,
        reserved: UInt8 = 0,
        release: UInt16 = 0
    ) {
        self.major = major
        self.minor = minor
        self.build = build
        self.reserved = reserved
        self.release = release
    }
}

private struct SMCPowerLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0

    nonisolated init(
        version: UInt16 = 0,
        length: UInt16 = 0,
        cpuPLimit: UInt32 = 0,
        gpuPLimit: UInt32 = 0,
        memPLimit: UInt32 = 0
    ) {
        self.version = version
        self.length = length
        self.cpuPLimit = cpuPLimit
        self.gpuPLimit = gpuPLimit
        self.memPLimit = memPLimit
    }
}

private struct SMCParamStruct {
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
