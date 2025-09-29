//
//  MouseModels.swift
//  macos-support-tools
//
//  Created by Jacob Massih on 2025-09-28.
//

import Foundation
import IOKit.hid

// Mouse button actions for side buttons
enum MouseButtonAction: CaseIterable, Codable {
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
enum MouseButtonType: CaseIterable {
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