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

/// Health of the mouse event taps. A tap is only installed while some enabled
/// feature needs it, so "not installed" is a normal idle state rather than a
/// fault; `isFault` is what the UI should colour on.
enum MouseTapStatus: Equatable {
    case active
    case idle
    case accessibilityRequired
    case unavailable
    case disabledAfterRepeatedTimeouts

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .idle: return "Idle - No mouse features enabled"
        case .accessibilityRequired: return "Inactive - Accessibility permission required"
        case .unavailable: return "Inactive - Event tap unavailable"
        case .disabledAfterRepeatedTimeouts: return "Disabled - Event tap kept timing out"
        }
    }

    var isFault: Bool {
        switch self {
        case .active, .idle: return false
        case .accessibilityRequired, .unavailable, .disabledAfterRepeatedTimeouts: return true
        }
    }
}

/// Everything the mouse tap callbacks need, flattened to plain values.
///
/// The callbacks run on `EventTapThread`, so they cannot read `MouseManager`:
/// SwiftUI mutates that observable state on the main thread. `MouseManager`
/// publishes a fresh snapshot whenever an input to it changes. A `nil` action
/// means the button is passed through untouched.
nonisolated struct MouseTapSettings: Equatable, Sendable {
    var shouldReverseScroll = false
    var button4Action: MouseButtonAction?
    var button5Action: MouseButtonAction?
}

// Mouse button actions for side buttons
nonisolated enum MouseButtonAction: CaseIterable, Codable, Hashable, Sendable {
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
