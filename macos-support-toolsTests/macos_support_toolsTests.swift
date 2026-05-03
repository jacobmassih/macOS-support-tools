//
//  macos_support_toolsTests.swift
//  macos-support-toolsTests
//
//  Created by Jacob Massih on 2025-09-26.
//

import Testing
import CoreGraphics
import Foundation
@testable import macos_support_tools

struct macos_support_toolsTests {

    @Test func keyboardCallbackAllowsKeyboardEventsWhenManagerRefconIsMissing() throws {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

        let returnedEvent = keyboardEventCallback(
            proxy: CGEventTapProxy(bitPattern: 1)!,
            type: .keyDown,
            event: event,
            refcon: nil
        )?.takeRetainedValue()

        #expect(returnedEvent != nil)
    }

    @Test func keyboardCallbackAllowsTapDisabledEventsWhenManagerRefconIsMissing() throws {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))

        let returnedEvent = keyboardEventCallback(
            proxy: CGEventTapProxy(bitPattern: 1)!,
            type: .tapDisabledByTimeout,
            event: event,
            refcon: nil
        )?.takeRetainedValue()

        #expect(returnedEvent != nil)
    }

    @Test func eventTapSnapshotReflectsScrollConfiguration() {
        let manager = MouseManager()

        manager.isAnyExternalMouseConnected = true
        manager.naturalScrollEnabled = false

        #expect(manager.currentEventTapSnapshot().shouldReverseScroll == true)

        manager.naturalScrollEnabled = true

        #expect(manager.currentEventTapSnapshot().shouldReverseScroll == false)
    }

    @Test func eventTapSnapshotReflectsMouseButtonConfiguration() {
        let manager = MouseManager()
        let device = MouseDevice(
            id: "test-mouse",
            name: "Test Mouse",
            vendorID: 1,
            productID: 2,
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

        manager.connectedDevices = [device]
        manager.mouseButtonsEnabled = false
        manager.citrixPassthroughEnabled = false

        let snapshot = manager.currentEventTapSnapshot()

        #expect(snapshot.mouseButtonsEnabled == false)
        #expect(snapshot.citrixPassthroughEnabled == false)
        #expect(snapshot.button4Enabled == true)
        #expect(snapshot.button4Action == .forward)
        #expect(snapshot.button5Enabled == true)
        #expect(snapshot.button5Action == .back)
    }

}
