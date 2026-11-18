import Foundation
import CoreAudio
import IOKit
import IOKit.hid

final class HIDMouseDeviceMonitor {
    private weak var manager: MouseManager?
    private var hidManager: IOHIDManager?

    init(manager: MouseManager) {
        self.manager = manager
    }

    func start() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let hidManager else { return }

        let deviceMatching = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse
        ] as CFDictionary

        IOHIDManagerSetDeviceMatching(hidManager, deviceMatching)

        guard let manager else { return }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(manager).toOpaque())

        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, deviceAddedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hidManager, deviceRemovedCallback, context)

        // Only subscribe to the two side buttons. HID usage numbers start at one.
        let sideButtons = [4, 5].map { usage in
            [kIOHIDElementUsagePageKey: kHIDPage_Button, kIOHIDElementUsageKey: usage]
        }
        IOHIDManagerSetInputValueMatchingMultiple(hidManager, sideButtons as CFArray)
        IOHIDManagerRegisterInputValueCallback(hidManager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context, IOHIDValueGetIntegerValue(value) != 0 else { return }
            let element = IOHIDValueGetElement(value)
            let device = IOHIDElementGetDevice(element)
            let manager = Unmanaged<MouseManager>.fromOpaque(context).takeUnretainedValue()
            manager.recordSideButton(deviceID: device.deviceID,
                                     button: Int64(IOHIDElementGetUsage(element)) - 1,
                                     timestamp: AudioConvertHostTimeToNanos(IOHIDValueGetTimeStamp(value)))
        }, context)

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        detectInitialDevices()
    }

    func stop() {
        guard let hidManager else { return }

        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidManager = nil
    }

    private func detectInitialDevices() {
        guard let manager else { return }

        let detectedDevices = currentIOHIDDevices().compactMap { device in
            manager.createMouseDevice(from: device)
        }

        manager.setDetectedDevices(detectedDevices)
    }

    private func currentIOHIDDevices() -> [IOHIDDevice] {
        guard let hidManager,
              let devices = IOHIDManagerCopyDevices(hidManager) else {
            return []
        }

        let deviceCount = CFSetGetCount(devices)
        guard deviceCount > 0 else {
            return []
        }

        let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: deviceCount)
        defer { values.deallocate() }
        CFSetGetValues(devices, values)

        return (0..<deviceCount).compactMap { index -> IOHIDDevice? in
            guard let devicePointer = values[index] else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(devicePointer).takeUnretainedValue()
        }
    }
}
