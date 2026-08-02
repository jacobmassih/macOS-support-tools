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

// Scroll wheel deltas, named after the axis they represent rather than the
// CGEvent field: axis 1 is vertical, axis 2 is horizontal.
nonisolated struct ScrollWheelDeltas: Equatable, Sendable {
    let vertical: Double
    let horizontal: Double

    var isZero: Bool {
        vertical == 0 && horizontal == 0
    }

    var reversed: ScrollWheelDeltas {
        ScrollWheelDeltas(vertical: vertical * -1, horizontal: horizontal * -1)
    }
}

nonisolated struct ScrollEventDescriptor: Equatable, Sendable {
    let deltas: ScrollWheelDeltas
    let pointDeltas: ScrollWheelDeltas
    let scrollPhase: Int64
    let momentumPhase: Int64
}

// The deltas to write back to an event, or nil for `pointDeltas` when the
// event carries none and they should be left alone.
nonisolated struct ScrollReversal: Equatable, Sendable {
    let deltas: ScrollWheelDeltas
    let pointDeltas: ScrollWheelDeltas?
}

nonisolated enum ScrollReversalPolicy {
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
