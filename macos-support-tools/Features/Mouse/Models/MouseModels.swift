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

// Scroll wheel deltas, named after the axis they represent rather than the
// CGEvent field: axis 1 is vertical, axis 2 is horizontal.
struct ScrollWheelDeltas: Equatable {
    let vertical: Double
    let horizontal: Double

    var isZero: Bool {
        vertical == 0 && horizontal == 0
    }

    var reversed: ScrollWheelDeltas {
        ScrollWheelDeltas(vertical: vertical * -1, horizontal: horizontal * -1)
    }
}

struct ScrollEventDescriptor: Equatable {
    let deltas: ScrollWheelDeltas
    let pointDeltas: ScrollWheelDeltas
    let scrollPhase: Int64
    let momentumPhase: Int64
}

// The deltas to write back to an event, or nil for `pointDeltas` when the
// event carries none and they should be left alone.
struct ScrollReversal: Equatable {
    let deltas: ScrollWheelDeltas
    let pointDeltas: ScrollWheelDeltas?
}

enum ScrollReversalPolicy {
    // Mouse wheels report whole-number deltas; anything smaller is a trackpad
    // gesture that macOS already handles via natural scrolling.
    private static let discreteTolerance = 0.01
    private static let minimumWheelDelta = 1.0

    static func reversal(for descriptor: ScrollEventDescriptor) -> ScrollReversal? {
        // Momentum phases only appear on trackpad scrolls - skip those entirely.
        guard descriptor.scrollPhase == 0, descriptor.momentumPhase == 0 else {
            return nil
        }

        guard isDiscreteScrolling(descriptor.deltas), hasWheelSizedDelta(descriptor.deltas) else {
            return nil
        }

        return ScrollReversal(
            deltas: descriptor.deltas.reversed,
            pointDeltas: descriptor.pointDeltas.isZero ? nil : descriptor.pointDeltas.reversed
        )
    }

    private static func isDiscreteScrolling(_ deltas: ScrollWheelDeltas) -> Bool {
        isNearWholeNumber(deltas.vertical) || isNearWholeNumber(deltas.horizontal)
    }

    private static func hasWheelSizedDelta(_ deltas: ScrollWheelDeltas) -> Bool {
        abs(deltas.vertical) >= minimumWheelDelta || abs(deltas.horizontal) >= minimumWheelDelta
    }

    private static func isNearWholeNumber(_ value: Double) -> Bool {
        abs(value - round(value)) < discreteTolerance
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
