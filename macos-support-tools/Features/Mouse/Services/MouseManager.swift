import Foundation
import IOKit.hid
import CoreGraphics
import AppKit
import Observation

@Observable class MouseManager {
    enum DefaultsKey {
        static let mouseButtonsEnabled = "MouseButtonsEnabled"
        static let naturalScrollEnabled = "NaturalScrollEnabled"
        static let citrixPassthroughEnabled = "CitrixPassthroughEnabled"
    }

    var connectedDevices: [MouseDevice] = []
    var deviceSettings: [String: MouseDevice] = [:]
    var isAnyExternalMouseConnected: Bool { !connectedDevices.isEmpty }
    var isAccessibilityEnabled: Bool {
        accessibilityManager.isAccessibilityEnabled
    }
    var tapStatus = MouseTapStatus.idle
    var mouseButtonsEnabled = true {
        didSet {
            userDefaults.set(mouseButtonsEnabled, forKey: DefaultsKey.mouseButtonsEnabled)
            syncTapConfiguration()
        }
    }
    var naturalScrollEnabled = true {
        didSet {
            userDefaults.set(naturalScrollEnabled, forKey: DefaultsKey.naturalScrollEnabled)
            syncTapConfiguration()
        }
    }
    var citrixPassthroughEnabled = true {
        didSet {
            userDefaults.set(citrixPassthroughEnabled, forKey: DefaultsKey.citrixPassthroughEnabled)
            syncTapConfiguration()
        }
    }

    let citrixMonitor = CitrixMonitor()

    private let userDefaults: UserDefaults
    private let deviceStore: MouseDeviceStore
    @ObservationIgnored private let accessibilityManager: AccessibilityManager
    @ObservationIgnored private var hasStartedSystemServices = false
    @ObservationIgnored private var accessibilityPermissionObserverID: UUID?
    @ObservationIgnored private var deviceMonitor: HIDMouseDeviceMonitor!
    @ObservationIgnored private(set) var eventTapController: MouseEventTapController!

    init(
        userDefaults: UserDefaults = .standard,
        deviceStore: MouseDeviceStore? = nil,
        accessibilityManager: AccessibilityManager
    ) {
        self.userDefaults = userDefaults
        self.deviceStore = deviceStore ?? MouseDeviceStore(userDefaults: userDefaults)
        self.accessibilityManager = accessibilityManager
        self.deviceMonitor = HIDMouseDeviceMonitor(manager: self)
        self.eventTapController = MouseEventTapController { [weak self] in
            // A tap can be left disabled from the tap thread, so bring the news
            // back to the main thread before touching observable state.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.updateTapStatus()
                }
            }
        }
        self.accessibilityPermissionObserverID = self.accessibilityManager.observePermissionChanges { [weak self] _ in
            self?.handleAccessibilityPermissionDidChange()
        }
        self.citrixMonitor.onCitrixActiveChange = { [weak self] in
            self?.syncTapConfiguration()
        }

        userDefaults.register(defaults: [
            DefaultsKey.mouseButtonsEnabled: true,
            DefaultsKey.naturalScrollEnabled: true,
            DefaultsKey.citrixPassthroughEnabled: true
        ])

        loadDeviceSettings()

        naturalScrollEnabled = userDefaults.bool(forKey: DefaultsKey.naturalScrollEnabled)
        mouseButtonsEnabled = userDefaults.bool(forKey: DefaultsKey.mouseButtonsEnabled)
        citrixPassthroughEnabled = userDefaults.bool(forKey: DefaultsKey.citrixPassthroughEnabled)
        updateTapStatus()
    }

    deinit {
        if let accessibilityPermissionObserverID {
            accessibilityManager.removePermissionChangeHandler(accessibilityPermissionObserverID)
        }
        eventTapController.disableAllTaps()
        deviceMonitor.stop()
    }

    func startSystemServices() {
        guard !hasStartedSystemServices else { return }

        hasStartedSystemServices = true
        deviceMonitor.start()
        syncTapConfiguration()
    }

    private func handleAccessibilityPermissionDidChange() {
        syncTapConfiguration()
        updateTapStatus()
    }

    func updateButtonSettings(for deviceId: String, buttonType: MouseButtonType, enabled: Bool) {
        guard var device = deviceSettings[deviceId] else { return }

        switch buttonType {
        case .button4:
            device.button4Enabled = enabled
        case .button5:
            device.button5Enabled = enabled
        }

        deviceSettings[deviceId] = device
        updateConnectedDevice(device)
        saveDeviceSettings()
        syncTapConfiguration()
    }

    func updateButtonAction(for deviceId: String, buttonType: MouseButtonType, action: MouseButtonAction) {
        guard var device = deviceSettings[deviceId] else { return }

        switch buttonType {
        case .button4:
            device.button4Action = action
        case .button5:
            device.button5Action = action
        }

        deviceSettings[deviceId] = device
        updateConnectedDevice(device)
        saveDeviceSettings()
        syncTapConfiguration()
    }

    internal func createMouseDevice(from ioDevice: IOHIDDevice) -> MouseDevice? {
        guard HIDDeviceClassifier.isExternalMouseCandidate(ioDevice.deviceDescriptor) else {
            return nil
        }

        return MouseDevice(
            id: ioDevice.deviceID,
            name: ioDevice.productString ?? "Unknown Device",
            vendorID: ioDevice.vendorID,
            productID: ioDevice.productID,
            button4Enabled: true,
            button5Enabled: true,
            button4Action: .forward,
            button5Action: .back
        )
    }

    internal func addDevice(_ device: MouseDevice) {
        guard !connectedDevices.contains(where: { $0.id == device.id }) else {
            return
        }

        let restoredDevice = restoredDeviceSettings(for: device)
        connectedDevices.append(restoredDevice)
        deviceSettings[device.id] = restoredDevice
        saveDeviceSettings()
        syncTapConfiguration()
    }

    internal func removeDevice(withID id: String) {
        connectedDevices.removeAll { $0.id == id }
        syncTapConfiguration()
    }

    internal func setDetectedDevices(_ devices: [MouseDevice]) {
        connectedDevices.removeAll()
        devices.forEach(addDevice)
        syncTapConfiguration()
    }

    internal func getCurrentActiveDevice() -> MouseDevice? {
        connectedDevices.first
    }

    internal func shouldReverseScroll() -> Bool {
        isScrollTapNeeded
    }

    internal func updateTapStatus() {
        if !isAccessibilityEnabled {
            tapStatus = eventTapController.needsAnyMouseEventTap ? .accessibilityRequired : .idle
        } else if eventTapController.isDisabledByRepeatedTimeouts {
            tapStatus = .disabledAfterRepeatedTimeouts
        } else if !eventTapController.needsAnyMouseEventTap {
            tapStatus = .idle
        } else if eventTapController.hasRequiredMouseEventTaps {
            tapStatus = .active
        } else {
            tapStatus = .unavailable
        }
    }

    /// A tap only needs to see scroll events while it would actually rewrite one.
    private var isScrollTapNeeded: Bool {
        isAnyExternalMouseConnected && !naturalScrollEnabled
    }

    /// Likewise for side buttons: with no connected device configured to override
    /// one, the tap would forward every click untouched.
    private var isButtonTapNeeded: Bool {
        mouseButtonsEnabled && connectedDevices.contains { $0.button4Enabled || $0.button5Enabled }
    }

    /// Republishes what the tap callbacks read and matches the installed taps to
    /// what the enabled features need. Every input to either decision calls this.
    private func syncTapConfiguration() {
        eventTapController.updateSettings(mouseTapSettings())

        guard hasStartedSystemServices else { return }

        eventTapController.updateTaps(
            scrollTapNeeded: isScrollTapNeeded,
            buttonTapNeeded: isButtonTapNeeded,
            isAccessibilityEnabled: isAccessibilityEnabled
        )
        updateTapStatus()
    }

    private func mouseTapSettings() -> MouseTapSettings {
        let activeDevice = getCurrentActiveDevice()
        let isCitrixPassthroughActive = citrixPassthroughEnabled && citrixMonitor.isCitrixActive
        let canOverrideButtons = mouseButtonsEnabled && !isCitrixPassthroughActive

        return MouseTapSettings(
            shouldReverseScroll: isScrollTapNeeded,
            button4Action: canOverrideButtons && activeDevice?.button4Enabled == true
                ? activeDevice?.button4Action
                : nil,
            button5Action: canOverrideButtons && activeDevice?.button5Enabled == true
                ? activeDevice?.button5Action
                : nil
        )
    }

    private func updateConnectedDevice(_ device: MouseDevice) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == device.id }) else { return }
        connectedDevices[index] = device
    }

    private func restoredDeviceSettings(for device: MouseDevice) -> MouseDevice {
        deviceSettings[device.id] ?? device
    }

    private func loadDeviceSettings() {
        guard let savedSettings = deviceStore.load() else {
            return
        }

        deviceSettings = savedSettings
    }

    private func saveDeviceSettings() {
        deviceStore.save(deviceSettings)
    }

}
