//
//  SettingsNavigation.swift
//  macos-support-tools
//
//  Created by Codex on 2026-06-04.
//

import Foundation

enum SettingsNavigation {
    static let requestedNotification = Notification.Name("SettingsNavigationRequested")
    static let pendingTargetKey = "PendingSettingsNavigationTarget"
    static let cleanupTarget = "Cleanup"
    
    static func setPendingCleanupTarget() {
        UserDefaults.standard.set(cleanupTarget, forKey: pendingTargetKey)
    }
    
    static func notifyPendingTarget() {
        NotificationCenter.default.post(name: requestedNotification, object: nil)
    }
    
    static func consumePendingTarget() -> String? {
        let target = UserDefaults.standard.string(forKey: pendingTargetKey)
        UserDefaults.standard.removeObject(forKey: pendingTargetKey)
        return target
    }
}

