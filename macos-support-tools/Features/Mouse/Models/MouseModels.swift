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
    case custom
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .back: return "Back"
        case .forward: return "Forward"
        case .middleClick: return "Middle Click"
        case .custom: return "Custom"
        }
    }
}

// Mouse button types for configuration
enum MouseButtonType: CaseIterable, Hashable {
    case left
    case right
    case middle
    case button4
    case button5
    
    var displayName: String {
        switch self {
        case .left: return "Left Button"
        case .right: return "Right Button"
        case .middle: return "Middle Button"
        case .button4: return "Button 4 (Forward)"
        case .button5: return "Button 5 (Back)"
        }
    }
    
    var defaultAction: MouseButtonAction {
        switch self {
        case .left, .right, .middle: return .none
        case .button4: return .forward
        case .button5: return .back
        }
    }
}

// Device-specific configuration
struct MouseDevice: Codable, Identifiable {
    let id: String // Unique device identifier
    let name: String
    let vendorID: Int
    let productID: Int
    var naturalScrollEnabled: Bool
    var lastConnected: Date
    // Mouse button settings
    var leftButtonEnabled: Bool
    var rightButtonEnabled: Bool
    var middleButtonEnabled: Bool
    var button4Enabled: Bool
    var button5Enabled: Bool
    
    // Button actions
    var button4Action: MouseButtonAction
    var button5Action: MouseButtonAction
    
    var displayName: String {
        return "\(name) (\(String(format: "%04X", vendorID)):\(String(format: "%04X", productID)))"
    }
}
