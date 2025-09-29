//
//  MouseDevice+Extensions.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Foundation
import IOKit
import IOKit.hid

extension IOHIDDevice {
    var deviceID: String {
        let vendorID = self.vendorID
        let productID = self.productID
        return "\(vendorID)-\(productID)"
    }
    
    var vendorID: Int {
        IOHIDDeviceGetProperty(self, kIOHIDVendorIDKey as CFString) as? Int ?? 0
    }
    
    var productID: Int {
        IOHIDDeviceGetProperty(self, kIOHIDProductIDKey as CFString) as? Int ?? 0
    }
    
    var productString: String? {
        IOHIDDeviceGetProperty(self, kIOHIDProductKey as CFString) as? String
    }
}
