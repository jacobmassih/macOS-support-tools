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
    var isAnyExternalMouseConnected = false
    var accessibilityTrusted = false
    var aggressiveInversion = false
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
    var keyboardBlocked = false {
        didSet {
            if keyboardBlocked {
                eventTapController.setupKeyboardEventTap()
            } else {
                eventTapController.disableKeyboardEventTap()
            }
        }
    }

    let citrixMonitor = CitrixMonitor()

    private let userDefaults: UserDefaults
    private let deviceStore: MouseDeviceStore
    @ObservationIgnored private var deviceMonitor: HIDMouseDeviceMonitor!
    @ObservationIgnored private var eventTapController: MouseEventTapController!

    init(
        userDefaults: UserDefaults = .standard,
        deviceStore: MouseDeviceStore? = nil
    ) {
        self.userDefaults = userDefaults
        self.deviceStore = deviceStore ?? MouseDeviceStore(userDefaults: userDefaults)
        self.deviceMonitor = HIDMouseDeviceMonitor(manager: self)
        self.eventTapController = MouseEventTapController(manager: self)

        userDefaults.register(defaults: [
            DefaultsKey.mouseButtonsEnabled: true,
            DefaultsKey.naturalScrollEnabled: true,
            DefaultsKey.citrixPassthroughEnabled: true
        ])

        print("[MouseManager] Initialized and starting up.")
        refreshAccessibilityTrust(prompt: true)
        deviceMonitor.start()
        eventTapController.setupScrollEventTap()
        eventTapController.setupButtonEventTap()
        updateTapStatus()
        loadDeviceSettings()
        deviceMonitor.startPolling()

        naturalScrollEnabled = userDefaults.bool(forKey: DefaultsKey.naturalScrollEnabled)
        mouseButtonsEnabled = userDefaults.bool(forKey: DefaultsKey.mouseButtonsEnabled)
        citrixPassthroughEnabled = userDefaults.bool(forKey: DefaultsKey.citrixPassthroughEnabled)
    }

    deinit {
        eventTapController.disableScrollEventTap()
        eventTapController.disableButtonEventTap()
        eventTapController.disableKeyboardEventTap()
        deviceMonitor.stopPolling()
        deviceMonitor.stop()
    }

    func toggleScrollDirection() {
        naturalScrollEnabled.toggle()
    }

    func toggleMouseButtons() {
        mouseButtonsEnabled.toggle()
    }

    func refreshAccessibilityTrust(prompt: Bool = false) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        accessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        updateTapStatus()

        if accessibilityTrusted {
            eventTapController.setupScrollEventTap()
            eventTapController.setupButtonEventTap()
            if keyboardBlocked {
                eventTapController.setupKeyboardEventTap()
            }
        }
    }

    func updateButtonSettings(for deviceId: String, buttonType: MouseButtonType, enabled: Bool) {
        guard var device = deviceSettings[deviceId] else { return }

        switch buttonType {
        case .left:
            device.leftButtonEnabled = enabled
        case .right:
            device.rightButtonEnabled = enabled
        case .middle:
            device.middleButtonEnabled = enabled
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
        default:
            break
        }

        deviceSettings[deviceId] = device
        updateConnectedDevice(device)
        saveDeviceSettings()
    }

    internal func createMouseDevice(from ioDevice: IOHIDDevice) -> MouseDevice? {
        guard !ioDevice.isBuiltInDevice else {
            return nil
        }

        return MouseDevice(
            id: ioDevice.deviceID,
            name: ioDevice.productString ?? "Unknown Device",
            vendorID: ioDevice.vendorID,
            productID: ioDevice.productID,
            naturalScrollEnabled: true,
            lastConnected: Date(),
            leftButtonEnabled: true,
            rightButtonEnabled: true,
            middleButtonEnabled: true,
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

        connectedDevices.append(device)
        deviceSettings[device.id] = device
        isAnyExternalMouseConnected = !connectedDevices.isEmpty
        saveDeviceSettings()
    }

    internal func removeDevice(_ device: MouseDevice) {
        connectedDevices.removeAll { $0.id == device.id }
        deviceSettings.removeValue(forKey: device.id)
        isAnyExternalMouseConnected = !connectedDevices.isEmpty
        saveDeviceSettings()
    }

    internal func setDetectedDevices(_ devices: [MouseDevice]) {
        connectedDevices = uniqueDevices(devices)
        isAnyExternalMouseConnected = !connectedDevices.isEmpty
    }

    internal func removeDisconnectedDevices(currentDeviceIDs: [String]) {
        for device in connectedDevices where !currentDeviceIDs.contains(device.id) {
            removeDevice(device)
        }

        isAnyExternalMouseConnected = !connectedDevices.isEmpty
    }

    internal func getCurrentActiveDevice() -> MouseDevice? {
        connectedDevices.first
    }

    internal func shouldReverseScroll() -> Bool {
        isAnyExternalMouseConnected && !naturalScrollEnabled
    }

    internal func updateTapStatus() {
        if !accessibilityTrusted {
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

    private func loadDeviceSettings() {
        guard let savedSettings = deviceStore.load() else {
            return
        }

        deviceSettings = savedSettings

        for (index, device) in connectedDevices.enumerated() {
            if let savedDevice = deviceSettings[device.id] {
                connectedDevices[index] = savedDevice
            }
        }
    }

    private func saveDeviceSettings() {
        deviceStore.save(deviceSettings)
    }
}
