import AppKit
import Testing
@testable import macos_support_tools

@MainActor
struct SettingsWindowDockTests {
    @Test func settingsWindowControlsDockAcrossCloseAndReopen() {
        let center = NotificationCenter()
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = SettingsWindowDockController(notificationCenter: center) {
            policies.append($0)
        }
        let window = NSWindow()
        controller.observe(nil)
        #expect(policies.isEmpty)
        controller.observe(window)
        #expect(policies == [.regular])

        center.post(name: NSWindow.didResignKeyNotification, object: window)
        center.post(name: NSWindow.didMiniaturizeNotification, object: window)
        center.post(name: NSWindow.didDeminiaturizeNotification, object: window)
        #expect(policies == [.regular])

        center.post(name: NSWindow.willCloseNotification, object: window)
        #expect(policies == [.regular, .accessory])
        center.post(name: NSWindow.didBecomeKeyNotification, object: window)
        #expect(policies == [.regular, .accessory, .regular])
    }

    @Test func ignoresOtherWindowsAndDetachesOldObservers() {
        let center = NotificationCenter()
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = SettingsWindowDockController(notificationCenter: center) {
            policies.append($0)
        }
        let first = NSWindow()
        let second = NSWindow()
        controller.observe(first)
        controller.observe(first)
        center.post(name: NSWindow.willCloseNotification, object: second)
        #expect(policies == [.regular])

        controller.observe(second)
        center.post(name: NSWindow.willCloseNotification, object: first)
        #expect(policies == [.regular, .regular])
        controller.observe(nil)
        center.post(name: NSWindow.willCloseNotification, object: second)
        #expect(policies == [.regular, .regular])
    }
}
