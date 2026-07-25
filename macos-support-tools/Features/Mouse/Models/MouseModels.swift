import Foundation
import IOKit.hid

struct HIDDeviceDescriptor {
    let productName: String?
    let primaryUsagePage: Int
    let primaryUsage: Int
    let isBuiltIn: Bool
}

enum HIDDeviceClassifier {
    static func isExternalMouseCandidate(_ descriptor: HIDDeviceDescriptor) -> Bool {
        guard !descriptor.isBuiltIn else {
            return false
        }

        if isKeyboardUsage(descriptor) || hasKeyboardProductName(descriptor.productName) {
            return false
        }

        if descriptor.primaryUsagePage == kHIDPage_GenericDesktop {
            return descriptor.primaryUsage == kHIDUsage_GD_Mouse
                || descriptor.primaryUsage == kHIDUsage_GD_Pointer
        }

        return hasMouseProductName(descriptor.productName)
    }

    private static func isKeyboardUsage(_ descriptor: HIDDeviceDescriptor) -> Bool {
        descriptor.primaryUsagePage == kHIDPage_GenericDesktop
            && (
                descriptor.primaryUsage == kHIDUsage_GD_Keyboard
                    || descriptor.primaryUsage == kHIDUsage_GD_Keypad
            )
    }

    private static func hasKeyboardProductName(_ productName: String?) -> Bool {
        guard let productName else {
            return false
        }

        let name = productName.localizedLowercase
        return name.contains("keyboard")
    }

    private static func hasMouseProductName(_ productName: String?) -> Bool {
        guard let productName else {
            return false
        }

        let name = productName.localizedLowercase
        return name.contains("mouse")
            || name.contains("trackball")
            || name.contains("pointing")
    }
}

// Mouse button actions for side buttons
enum MouseButtonAction: CaseIterable, Codable, Hashable {
    case none
    case back
    case forward
    case middleClick
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .back: return "Back"
        case .forward: return "Forward"
        case .middleClick: return "Middle Click"
        }
    }
}

// Mouse button types for configuration
enum MouseButtonType: CaseIterable, Hashable {
    case button4
    case button5
}

// Device-specific configuration
struct MouseDevice: Codable, Identifiable {
    let id: String // Unique device identifier
    let name: String
    let vendorID: Int
    let productID: Int
    // Mouse button settings
    var button4Enabled: Bool
    var button5Enabled: Bool

    // Button actions
    var button4Action: MouseButtonAction
    var button5Action: MouseButtonAction
}
