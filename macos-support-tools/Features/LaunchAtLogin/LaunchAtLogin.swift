import AppKit
import Foundation
import ServiceManagement
import Observation

@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool = false

    @ObservationIgnored private let isRegistered: () -> Bool
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private var appActivationObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        isRegistered: @escaping () -> Bool = { SMAppService.mainApp.status == .enabled }
    ) {
        self.notificationCenter = notificationCenter
        self.isRegistered = isRegistered
        refresh()
        appActivationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let appActivationObserver {
            notificationCenter.removeObserver(appActivationObserver)
        }
    }

    func refresh() {
        isEnabled = isRegistered()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login status:", error)
        }

        refresh()
    }
}
