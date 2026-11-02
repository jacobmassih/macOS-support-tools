import AppKit
import SwiftUI

/// Track the Settings window itself, not SwiftUI appearance or focus. Losing
/// focus and minimizing must not remove the app from the Dock.
struct SettingsWindowDockView: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowDockObserverView {
        SettingsWindowDockObserverView()
    }

    func updateNSView(_ nsView: SettingsWindowDockObserverView, context: Context) {}
}

final class SettingsWindowDockObserverView: NSView {
    private let dockController = SettingsWindowDockController()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        dockController.observe(window)
    }
}

final class SettingsWindowDockController: NSObject {
    private weak var settingsWindow: NSWindow?
    private let notificationCenter: NotificationCenter
    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Void

    init(
        notificationCenter: NotificationCenter = .default,
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Void = {
            NSApp.setActivationPolicy($0)
        }
    ) {
        self.notificationCenter = notificationCenter
        self.setActivationPolicy = setActivationPolicy
        super.init()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func observe(_ window: NSWindow?) {
        guard settingsWindow !== window else { return }
        notificationCenter.removeObserver(self)
        settingsWindow = window
        guard let window else { return }

        notificationCenter.addObserver(
            self, selector: #selector(windowOpened),
            name: NSWindow.didBecomeKeyNotification, object: window
        )
        notificationCenter.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: window
        )
        // The initial attachment can precede the first key-window notification.
        // Keep LSUIElement enabled so launches without Settings remain menu-only.
        windowOpened()
    }

    @objc private func windowOpened() {
        setActivationPolicy(.regular)
    }

    @objc private func windowClosed() {
        // Keep observing: SwiftUI can reuse this same window when reopened.
        setActivationPolicy(.accessory)
    }
}
