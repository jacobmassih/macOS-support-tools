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
    var tapStatus = "Inactive"
    var mouseButtonsEnabled = true {
        didSet {
            userDefaults.set(mouseButtonsEnabled, forKey: DefaultsKey.mouseButtonsEnabled)
        }
    }
    var naturalScrollEnabled = true {
        didSet {
            userDefaults.set(naturalScrollEnabled, forKey: DefaultsKey.naturalScrollEnabled)
        }
    }
    var citrixPassthroughEnabled = true {
        didSet {
            userDefaults.set(citrixPassthroughEnabled, forKey: DefaultsKey.citrixPassthroughEnabled)
        }
    }

    let citrixMonitor = CitrixMonitor()

    private let userDefaults: UserDefaults
    private let deviceStore: MouseDeviceStore
    @ObservationIgnored private let accessibilityManager: AccessibilityManager
    @ObservationIgnored private var hasStartedSystemServices = false
    @ObservationIgnored private var accessibilityPermissionObserverID: UUID?
    @ObservationIgnored private var deviceMonitor: HIDMouseDeviceMonitor!
    @ObservationIgnored private var eventTapController: MouseEventTapController!

    init(
        userDefaults: UserDefaults = .standard,
        deviceStore: MouseDeviceStore? = nil,
        accessibilityManager: AccessibilityManager
    ) {
        self.userDefaults = userDefaults
        self.deviceStore = deviceStore ?? MouseDeviceStore(userDefaults: userDefaults)
        self.accessibilityManager = accessibilityManager
        self.deviceMonitor = HIDMouseDeviceMonitor(manager: self)
        self.eventTapController = MouseEventTapController(manager: self)
        self.accessibilityPermissionObserverID = self.accessibilityManager.observePermissionChanges { [weak self] _ in
            self?.handleAccessibilityPermissionDidChange()
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
        eventTapController.disableScrollEventTap()
        eventTapController.disableButtonEventTap()
        deviceMonitor.stop()
    }

    func startSystemServices() {
        guard !hasStartedSystemServices else { return }

        hasStartedSystemServices = true
        deviceMonitor.start()
        eventTapController.setupScrollEventTap()
        eventTapController.setupButtonEventTap()
        updateTapStatus()
    }

    private func handleAccessibilityPermissionDidChange() {
        updateTapStatus()

        if hasStartedSystemServices && isAccessibilityEnabled {
            eventTapController.setupScrollEventTap()
            eventTapController.setupButtonEventTap()
        }
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
    }

    internal func removeDevice(_ device: MouseDevice) {
        connectedDevices.removeAll { $0.id == device.id }
    }

    internal func setDetectedDevices(_ devices: [MouseDevice]) {
        connectedDevices = uniqueDevices(devices).map(restoredDeviceSettings(for:))
    }
    internal func removeDisconnectedDevices(currentDeviceIDs: Set<String>) {
        connectedDevices.removeAll { !currentDeviceIDs.contains($0.id) }
    }
    internal func getCurrentActiveDevice() -> MouseDevice? {
        connectedDevices.first
    }

    internal func shouldReverseScroll() -> Bool {
        isAnyExternalMouseConnected && !naturalScrollEnabled
    }

    internal func reenableScrollEventTap() {
        eventTapController.reenableScrollEventTap()
    }

    internal func reenableButtonEventTap() {
        eventTapController.reenableButtonEventTap()
    }

    internal func updateTapStatus() {
        if !isAccessibilityEnabled {
            tapStatus = "Inactive - Accessibility permission required"
        } else if eventTapController.hasRequiredMouseEventTaps {
            tapStatus = "Active"
        } else {
            tapStatus = "Inactive - Event tap unavailable"
        }
    }

    private func updateConnectedDevice(_ device: MouseDevice) {
        guard let index = connectedDevices.firstIndex(where: { $0.id == device.id }) else { return }
        connectedDevices[index] = device
    }

    private func uniqueDevices(_ devices: [MouseDevice]) -> [MouseDevice] {
        var seenIDs = Set<String>()

        return devices.filter { device in
            seenIDs.insert(device.id).inserted
        }
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
