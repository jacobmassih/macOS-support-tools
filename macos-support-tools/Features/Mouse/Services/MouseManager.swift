import Foundation
import IOKit.hid
import CoreAudio
import CoreGraphics
import AppKit
import Observation

@Observable class MouseManager {
    enum DefaultsKey {
        static let mouseButtonsEnabled = "MouseButtonsEnabled"
        static let naturalScrollEnabled = "NaturalScrollEnabled"
        static let citrixPassthroughEnabled = "CitrixPassthroughEnabled"
    }

    var connectedDevices: [MouseDevice] = [] {
        didSet { updateMouseEventTaps() }
    }
    var deviceSettings: [String: MouseDevice] = [:]
    var isAnyExternalMouseConnected: Bool { !connectedDevices.isEmpty }
    var isAccessibilityEnabled: Bool {
        accessibilityManager.isAccessibilityEnabled
    }
    var tapStatus = "Inactive"
    var mouseButtonsEnabled: Bool {
        didSet {
            userDefaults.set(mouseButtonsEnabled, forKey: DefaultsKey.mouseButtonsEnabled)
            updateMouseEventTaps()
        }
    }
    var naturalScrollEnabled: Bool {
        didSet {
            userDefaults.set(naturalScrollEnabled, forKey: DefaultsKey.naturalScrollEnabled)
            updateMouseEventTaps()
        }
    }
    var citrixPassthroughEnabled: Bool {
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
    @ObservationIgnored private var eventTapController: (any MouseEventTapControlling)!

    init(
        userDefaults: UserDefaults = .standard,
        deviceStore: MouseDeviceStore? = nil,
        accessibilityManager: AccessibilityManager,
        eventTapController: (any MouseEventTapControlling)? = nil
    ) {
        self.userDefaults = userDefaults
        self.deviceStore = deviceStore ?? MouseDeviceStore(userDefaults: userDefaults)
        self.accessibilityManager = accessibilityManager

        userDefaults.register(defaults: [
            DefaultsKey.mouseButtonsEnabled: true,
            DefaultsKey.naturalScrollEnabled: true,
            DefaultsKey.citrixPassthroughEnabled: true
        ])

        // These are initialised, not assigned, so the `didSet` observers stay
        // silent: assigning would write the registered fallbacks back into the
        // persistent domain and turn a code-owned default into a stored value
        // the user never chose.
        self.naturalScrollEnabled = userDefaults.bool(forKey: DefaultsKey.naturalScrollEnabled)
        self.mouseButtonsEnabled = userDefaults.bool(forKey: DefaultsKey.mouseButtonsEnabled)
        self.citrixPassthroughEnabled = userDefaults.bool(forKey: DefaultsKey.citrixPassthroughEnabled)

        self.deviceMonitor = HIDMouseDeviceMonitor(manager: self)
        self.eventTapController = eventTapController ?? MouseEventTapController(manager: self)
        self.accessibilityPermissionObserverID = self.accessibilityManager.observePermissionChanges { [weak self] _ in
            self?.handleAccessibilityPermissionDidChange()
        }

        loadDeviceSettings()
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
        updateMouseEventTaps()
    }

    private func handleAccessibilityPermissionDidChange() {
        updateMouseEventTaps()
    }

    private var needsButtonEventTap: Bool {
        mouseButtonsEnabled && connectedDevices.contains { device in
            (device.button4Enabled && device.button4Action != .none)
                || (device.button5Enabled && device.button5Action != .none)
        }
    }

    private func updateMouseEventTaps() {
        guard hasStartedSystemServices else {
            updateTapStatus()
            return
        }

        if isAccessibilityEnabled && shouldReverseScroll() {
            eventTapController.setupScrollEventTap()
        } else {
            eventTapController.disableScrollEventTap()
        }

        if isAccessibilityEnabled && needsButtonEventTap {
            eventTapController.setupButtonEventTap()
        } else {
            eventTapController.disableButtonEventTap()
        }
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

    internal func removeDevice(withID id: String) {
        recentPresses.removeAll { $0.deviceID == id }
        connectedDevices.removeAll { $0.id == id }
    }

    internal func setDetectedDevices(_ devices: [MouseDevice]) {
        connectedDevices.removeAll()
        devices.forEach(addDevice)
    }
    
    private struct SideButtonPress {
        let deviceID: String
        let button: Int64
        let timestamp: UInt64
    }

    @ObservationIgnored private var recentPresses: [SideButtonPress] = []

    func recordSideButton(deviceID: String, usage: UInt32, value: Int, hostTime: UInt64) {
        guard value != 0, (4...5).contains(usage) else { return }
        // HID uses one-based button usages and host ticks. Quartz uses zero-based
        // button numbers and nanoseconds.
        let button = Int64(usage) - 1
        let timestamp = AudioConvertHostTimeToNanos(hostTime)
        if recentPresses.count >= 32 { recentPresses.removeFirst() }
        recentPresses.append(SideButtonPress(deviceID: deviceID, button: button, timestamp: timestamp))
    }

    func deviceForPress(button: Int64, timestamp: UInt64) -> MouseDevice? {
        let matches = recentPresses.filter { $0.timestamp == timestamp && $0.button == button }
        recentPresses.removeAll { $0.timestamp == timestamp && $0.button == button }
        if let first = matches.first {
            guard matches.allSatisfy({ $0.deviceID == first.deviceID }) else { return nil }
            return connectedDevices.first { $0.id == first.deviceID }
        }
        return connectedDevices.count == 1 ? connectedDevices.first : nil
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
        } else if !shouldReverseScroll() && !needsButtonEventTap {
            tapStatus = "Inactive - No mouse features in use"
        } else if hasStartedSystemServices
                    && (!shouldReverseScroll() || eventTapController.isScrollTapInstalled)
                    && (!needsButtonEventTap || eventTapController.isButtonTapInstalled) {
            tapStatus = "Active"
        } else {
            tapStatus = "Inactive - Event tap unavailable"
        }
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
