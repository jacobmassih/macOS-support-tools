import Foundation
import IOKit
import IOKit.hid

extension IOHIDDevice {
    var deviceID: String {
        let serial = serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let serial, !serial.isEmpty {
            return "\(vendorID)-\(productID)-serial-\(serial)"
        }
        
        if locationID != 0 {
            return "\(vendorID)-\(productID)-location-\(locationID)"
        }
        
        return "\(vendorID)-\(productID)-registry-\(registryEntryID)"
    }
    
    var vendorID: Int {
        intProperty(kIOHIDVendorIDKey as CFString)
    }
    
    var productID: Int {
        intProperty(kIOHIDProductIDKey as CFString)
    }
    
    var productString: String? {
        IOHIDDeviceGetProperty(self, kIOHIDProductKey as CFString) as? String
    }

    var isBuiltInDevice: Bool {
        boolProperty("Built-In" as CFString) || boolProperty("MT Built-In" as CFString)
    }
    
    private var serialNumber: String? {
        IOHIDDeviceGetProperty(self, kIOHIDSerialNumberKey as CFString) as? String
    }
    
    private var locationID: Int {
        intProperty(kIOHIDLocationIDKey as CFString)
    }
    
    private var registryEntryID: UInt64 {
        var entryID: UInt64 = 0
        let service = IOHIDDeviceGetService(self)
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        return entryID
    }
    
    private func intProperty(_ key: CFString) -> Int {
        guard let value = IOHIDDeviceGetProperty(self, key) else {
            return 0
        }
        
        if let number = value as? NSNumber {
            return number.intValue
        }
        
        return value as? Int ?? 0
    }

    private func boolProperty(_ key: CFString) -> Bool {
        guard let value = IOHIDDeviceGetProperty(self, key) else {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return value as? Bool ?? false
    }
}
