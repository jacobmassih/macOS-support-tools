import Foundation
import IOKit.hid
import Testing
@testable import macos_support_tools

struct macos_support_toolsTests {

    @Test func hidDeviceClassifierRejectsKeyboardDevices() {
        let keyboardUsage = HIDDeviceDescriptor(
            productName: "Magic Keyboard",
            primaryUsagePage: kHIDPage_GenericDesktop,
            primaryUsage: kHIDUsage_GD_Keyboard,
            isBuiltIn: false
        )
        let keyboardNamedMouseCollection = HIDDeviceDescriptor(
            productName: "USB Keyboard",
            primaryUsagePage: kHIDPage_GenericDesktop,
            primaryUsage: kHIDUsage_GD_Mouse,
            isBuiltIn: false
        )

        #expect(!HIDDeviceClassifier.isExternalMouseCandidate(keyboardUsage))
        #expect(!HIDDeviceClassifier.isExternalMouseCandidate(keyboardNamedMouseCollection))
    }

    @Test func hidDeviceClassifierAcceptsExternalMouseDevices() {
        let mouse = HIDDeviceDescriptor(
            productName: "MX Master 3S",
            primaryUsagePage: kHIDPage_GenericDesktop,
            primaryUsage: kHIDUsage_GD_Mouse,
            isBuiltIn: false
        )
        let pointer = HIDDeviceDescriptor(
            productName: "External Pointing Device",
            primaryUsagePage: kHIDPage_GenericDesktop,
            primaryUsage: kHIDUsage_GD_Pointer,
            isBuiltIn: false
        )

        #expect(HIDDeviceClassifier.isExternalMouseCandidate(mouse))
        #expect(HIDDeviceClassifier.isExternalMouseCandidate(pointer))
    }

    @Test func hidDeviceClassifierRejectsBuiltInDevices() {
        let builtInMouse = HIDDeviceDescriptor(
            productName: "Apple Internal Mouse",
            primaryUsagePage: kHIDPage_GenericDesktop,
            primaryUsage: kHIDUsage_GD_Mouse,
            isBuiltIn: true
        )

        #expect(!HIDDeviceClassifier.isExternalMouseCandidate(builtInMouse))
    }

    @Test func cleanupScanIncludesPackageDescendantSizes() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let appBundleURL = rootURL.appending(path: "LargeFixture.app", directoryHint: .isDirectory)
        let payloadDirectoryURL = appBundleURL.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        let payloadURL = payloadDirectoryURL.appending(path: "payload.bin")
        let payload = Data(repeating: 0xAB, count: 16 * 1024)

        try fileManager.createDirectory(at: payloadDirectoryURL, withIntermediateDirectories: true)
        try payload.write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let category = CleanupCategory(
            id: .trash,
            title: "Test Trash",
            subtitle: "Fixture category",
            systemImage: "trash",
            paths: [rootURL],
            riskLevel: .review
        )

        let result = try CleanupManager.scan(category: category)

        #expect(result.itemCount == 1)
        #expect(result.items.first?.url.resolvingSymlinksInPath() == appBundleURL.resolvingSymlinksInPath())
        #expect(result.totalBytes >= Int64(payload.count))
    }

    @Test func cleanupScanIgnoresZeroByteCandidates() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let emptyFileURL = rootURL.appending(path: "empty.tmp")
        let payloadURL = rootURL.appending(path: "payload.tmp")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data().write(to: emptyFileURL)
        try Data("payload".utf8).write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let category = CleanupCategory(
            id: .trash,
            title: "Test Trash",
            subtitle: "Fixture category",
            systemImage: "trash",
            paths: [rootURL],
            riskLevel: .review
        )

        let result = try CleanupManager.scan(category: category)

        #expect(result.itemCount == 1)
        #expect(result.items.map { $0.url.resolvingSymlinksInPath() } == [payloadURL.resolvingSymlinksInPath()])
        #expect(result.totalBytes > 0)
    }

    @Test func cleanupMovesDeletableItemsToTrash() throws {
        let firstURL = URL(filePath: "/tmp/cleanup-first")
        let secondURL = URL(filePath: "/tmp/cleanup-second")
        let firstItem = CleanupItem(url: firstURL, size: 1024, modifiedDate: nil)
        let secondItem = CleanupItem(url: secondURL, size: 2048, modifiedDate: nil)
        let recorder = TrashRecorder()

        let result = CleanupManager.clean(
            items: [firstItem, secondItem],
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { recorder.record($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [firstURL, secondURL])
        #expect(result.trashedBytes == 3072)
        #expect(result.skippedItems.isEmpty)
        #expect(recorder.urls == [firstURL, secondURL])
    }

    @Test func cleanupSkipsMissingAndPermissionDeniedItems() throws {
        let missingURL = URL(filePath: "/tmp/missing")
        let deniedURL = URL(filePath: "/tmp/denied")
        let allowedURL = URL(filePath: "/tmp/allowed")
        let missingItem = CleanupItem(url: missingURL, size: 1, modifiedDate: nil)
        let deniedItem = CleanupItem(url: deniedURL, size: 2, modifiedDate: nil)
        let allowedItem = CleanupItem(url: allowedURL, size: 4, modifiedDate: nil)
        let recorder = TrashRecorder()

        let result = CleanupManager.clean(
            items: [missingItem, deniedItem, allowedItem],
            fileClient: CleanupFileClient(
                fileExists: { $0 != missingURL },
                isDeletable: { $0 != deniedURL },
                trashItem: { recorder.record($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [allowedURL])
        #expect(result.skippedItems.map { $0.item.url } == [missingURL, deniedURL])
        #expect(result.skippedItems.map(\.reason) == ["Item no longer exists.", "Permission denied."])
        #expect(result.skippedBytes == 3)
        #expect(recorder.urls == [allowedURL])
    }

    @Test func cleanupReportsTrashErrorsAndContinues() throws {
        let failingURL = URL(filePath: "/tmp/failing")
        let succeedingURL = URL(filePath: "/tmp/succeeding")
        let failingItem = CleanupItem(url: failingURL, size: 8, modifiedDate: nil)
        let succeedingItem = CleanupItem(url: succeedingURL, size: 16, modifiedDate: nil)
        let recorder = TrashRecorder(failingURLs: [failingURL])

        let result = CleanupManager.clean(
            items: [failingItem, succeedingItem],
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { try recorder.recordOrThrow($0) }
            )
        )

        #expect(result.trashedItems.map(\.url) == [succeedingURL])
        #expect(result.skippedItems.map { $0.item.url } == [failingURL])
        #expect(result.skippedItems.first?.reason == "Trash failed for failing")
        #expect(recorder.urls == [failingURL, succeedingURL])
    }

    @Test func cleanupLiveClientMovesDisposableFileToTrash() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let disposableURL = rootURL.appending(path: "disposable-cleanup-file.txt")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("trash me".utf8).write(to: disposableURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let result = CleanupManager.clean(
            items: [
                CleanupItem(url: disposableURL, size: 8, modifiedDate: nil)
            ]
        )

        #expect(result.trashedItems.map(\.url) == [disposableURL])
        #expect(result.skippedItems.isEmpty)
        #expect(!fileManager.fileExists(atPath: disposableURL.path))
    }

    @Test @MainActor func cleanupManagerScansCustomCategoriesAndTracksTotals() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cacheDirectoryURL = rootURL.appending(path: "CacheBucket", directoryHint: .isDirectory)
        let payloadURL = cacheDirectoryURL.appending(path: "payload.bin")
        let payload = Data(repeating: 0xCD, count: 4096)

        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try payload.write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(categories: [
            CleanupCategory(
                id: .userCaches,
                title: "Caches",
                subtitle: "Test caches",
                systemImage: "shippingbox",
                paths: [rootURL],
                riskLevel: .safe
            )
        ])

        await manager.scan()

        #expect(!manager.isScanning)
        #expect(manager.lastError == nil)
        #expect(manager.lastScanDate != nil)
        #expect(manager.categories.count == 1)
        #expect(manager.scanResults.count == 1)
        #expect(manager.scanResults.first?.items.first?.url.resolvingSymlinksInPath() == cacheDirectoryURL.resolvingSymlinksInPath())
        #expect(manager.totalReclaimableBytes >= Int64(payload.count))
    }

    @Test @MainActor func cleanupManagerCleanRecordsResultAndRemovesTrashedScanItems() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let firstURL = rootURL.appending(path: "first.tmp")
        let secondURL = rootURL.appending(path: "second.tmp")
        let recorder = TrashRecorder()

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { $0.resolvingSymlinksInPath() == firstURL.resolvingSymlinksInPath() },
                trashItem: { recorder.record($0) }
            ),
            categories: [
                CleanupCategory(
                    id: .temporaryFiles,
                    title: "Temporary",
                    subtitle: "Test temporary files",
                    systemImage: "clock",
                    paths: [rootURL],
                    riskLevel: .safe
                )
            ]
        )

        await manager.scan()
        await manager.clean(items: manager.scanResults.flatMap(\.items))

        #expect(!manager.isCleaning)
        #expect(manager.lastCleanupResult?.trashedItems.map { $0.url.resolvingSymlinksInPath() } == [firstURL.resolvingSymlinksInPath()])
        #expect(manager.lastCleanupResult?.skippedItems.map { $0.item.url.resolvingSymlinksInPath() } == [secondURL.resolvingSymlinksInPath()])
        #expect(manager.scanResults.first?.items.map { $0.url.resolvingSymlinksInPath() } == [secondURL.resolvingSymlinksInPath()])
        #expect(manager.totalReclaimableBytes == manager.scanResults.first?.totalBytes)
        #expect(recorder.urls.map { $0.resolvingSymlinksInPath() } == [firstURL.resolvingSymlinksInPath()])
    }

    @Test @MainActor func cleanupManagerCleanHandlesEmptySelection() async {
        let manager = CleanupManager(categories: [])

        await manager.clean(items: [])

        #expect(manager.lastCleanupResult?.trashedItems.isEmpty == true)
        #expect(manager.lastCleanupResult?.skippedItems.isEmpty == true)
        #expect(!manager.isCleaning)
    }

    @Test @MainActor func cleanupManagerClearAllCachesRequiresScanAndOnlyCleansUserCaches() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cacheRootURL = rootURL.appending(path: "Caches", directoryHint: .isDirectory)
        let tempRootURL = rootURL.appending(path: "Temporary", directoryHint: .isDirectory)
        let cacheItemURL = cacheRootURL.appending(path: "cache-item")
        let tempItemURL = tempRootURL.appending(path: "temp-item")
        let recorder = TrashRecorder()

        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempRootURL, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cacheItemURL)
        try Data("temp".utf8).write(to: tempItemURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manager = CleanupManager(
            fileClient: CleanupFileClient(
                fileExists: { _ in true },
                isDeletable: { _ in true },
                trashItem: { recorder.record($0) }
            ),
            categories: [
                CleanupCategory(
                    id: .userCaches,
                    title: "Caches",
                    subtitle: "Test caches",
                    systemImage: "shippingbox",
                    paths: [cacheRootURL],
                    riskLevel: .safe
                ),
                CleanupCategory(
                    id: .temporaryFiles,
                    title: "Temporary",
                    subtitle: "Test temporary files",
                    systemImage: "clock",
                    paths: [tempRootURL],
                    riskLevel: .safe
                )
            ]
        )

        await manager.clearAllCaches()

        #expect(manager.lastError == "Run a scan before clearing caches.")
        #expect(manager.lastCleanupResult == nil)
        #expect(recorder.urls.isEmpty)
        #expect(fileManager.fileExists(atPath: cacheItemURL.path))
        #expect(fileManager.fileExists(atPath: tempItemURL.path))

        await manager.scan()
        await manager.clearAllCaches()

        #expect(manager.lastCleanupResult?.trashedItems.map { $0.url.resolvingSymlinksInPath() } == [cacheItemURL.resolvingSymlinksInPath()])
        #expect(manager.lastCleanupResult?.skippedItems.isEmpty == true)
        #expect(recorder.urls.map { $0.resolvingSymlinksInPath() } == [cacheItemURL.resolvingSymlinksInPath()])
    }

    @Test @MainActor func cleanupManagerDefaultCategoriesSelectExpectedPaths() {
        let manager = CleanupManager()
        let categoryIDs = manager.categories.map(\.id)

        #expect(categoryIDs == CleanupCategoryID.allCases)
        #expect(manager.categories.first?.paths.first?.lastPathComponent == "Caches")
        #expect(manager.categories.contains { $0.id == .temporaryFiles && $0.paths.count == 2 })
        #expect(manager.categories.contains { $0.id == .trash && $0.riskLevel == .review })
    }

    @Test func cleanupCatalogDefaultCategoriesStayInModelOrder() {
        let categories = CleanupCatalog.defaultCategories()

        #expect(categories.map(\.id) == CleanupCategoryID.allCases)
        #expect(categories.first?.paths.first?.lastPathComponent == "Caches")
        #expect(categories.contains { $0.id == .temporaryFiles && $0.paths.count == 2 })
        #expect(categories.contains { $0.id == .trash && $0.riskLevel == .review })
    }

    @Test func mouseDeviceStoreRoundTripsDeviceSettings() throws {
        let suiteName = "MouseDeviceStoreTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = MouseDeviceStore(userDefaults: userDefaults)
        let device = makeMouseDevice(
            naturalScrollEnabled: false,
            leftButtonEnabled: false,
            rightButtonEnabled: true,
            middleButtonEnabled: false,
            button4Enabled: false,
            button5Enabled: true,
            button4Action: .middleClick,
            button5Action: .back
        )

        store.save([device.id: device])
        let loadedDevice = store.load()?[device.id]

        #expect(loadedDevice?.id == device.id)
        #expect(loadedDevice?.name == device.name)
        #expect(loadedDevice?.vendorID == device.vendorID)
        #expect(loadedDevice?.productID == device.productID)
        #expect(loadedDevice?.naturalScrollEnabled == device.naturalScrollEnabled)
        #expect(loadedDevice?.lastConnected == device.lastConnected)
        #expect(loadedDevice?.leftButtonEnabled == device.leftButtonEnabled)
        #expect(loadedDevice?.rightButtonEnabled == device.rightButtonEnabled)
        #expect(loadedDevice?.middleButtonEnabled == device.middleButtonEnabled)
        #expect(loadedDevice?.button4Enabled == device.button4Enabled)
        #expect(loadedDevice?.button5Enabled == device.button5Enabled)
        #expect(loadedDevice?.button4Action == device.button4Action)
        #expect(loadedDevice?.button5Action == device.button5Action)
    }

    @Test func mouseManagerNaturalScrollTogglePersistsAndControlsExternalMouseReversal() throws {
        let suiteName = "MouseManagerNaturalScrollTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let device = makeMouseDevice()

        #expect(manager.naturalScrollEnabled)
        #expect(!manager.shouldReverseScroll())

        manager.setDetectedDevices([device])
        #expect(!manager.shouldReverseScroll())

        manager.toggleScrollDirection()
        #expect(!manager.naturalScrollEnabled)
        #expect(manager.shouldReverseScroll())
        #expect(!userDefaults.bool(forKey: MouseManager.DefaultsKey.naturalScrollEnabled))

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        reloadedManager.setDetectedDevices([device])
        #expect(!reloadedManager.naturalScrollEnabled)
        #expect(reloadedManager.shouldReverseScroll())
    }

    @Test func mouseManagerButtonSettingsAndActionsPersistPerDevice() throws {
        let suiteName = "MouseManagerButtonSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let device = makeMouseDevice()

        manager.addDevice(device)
        manager.updateButtonSettings(for: device.id, buttonType: .left, enabled: false)
        manager.updateButtonSettings(for: device.id, buttonType: .right, enabled: false)
        manager.updateButtonSettings(for: device.id, buttonType: .middle, enabled: false)
        manager.updateButtonSettings(for: device.id, buttonType: .button4, enabled: false)
        manager.updateButtonSettings(for: device.id, buttonType: .button5, enabled: false)
        manager.updateButtonAction(for: device.id, buttonType: .button4, action: .middleClick)
        manager.updateButtonAction(for: device.id, buttonType: .button5, action: .none)
        manager.toggleMouseButtons()

        let updatedDevice = try #require(manager.deviceSettings[device.id])
        #expect(!updatedDevice.leftButtonEnabled)
        #expect(!updatedDevice.rightButtonEnabled)
        #expect(!updatedDevice.middleButtonEnabled)
        #expect(!updatedDevice.button4Enabled)
        #expect(!updatedDevice.button5Enabled)
        #expect(updatedDevice.button4Action == .middleClick)
        #expect(updatedDevice.button5Action == .none)
        #expect(!manager.mouseButtonsEnabled)
        #expect(!userDefaults.bool(forKey: MouseManager.DefaultsKey.mouseButtonsEnabled))

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        let reloadedDevice = try #require(reloadedManager.deviceSettings[device.id])
        #expect(!reloadedDevice.leftButtonEnabled)
        #expect(!reloadedDevice.rightButtonEnabled)
        #expect(!reloadedDevice.middleButtonEnabled)
        #expect(!reloadedDevice.button4Enabled)
        #expect(!reloadedDevice.button5Enabled)
        #expect(reloadedDevice.button4Action == .middleClick)
        #expect(reloadedDevice.button5Action == .none)
        #expect(!reloadedManager.mouseButtonsEnabled)
    }

    @Test func keyboardDebounceFilterSuppressesFastDuplicateKeyDowns() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let bouncedAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_020_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let laterAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_060_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let fastSWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 1,
            timestamp: 1_070_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!firstAWasSuppressed)
        #expect(bouncedAWasSuppressed)
        #expect(!laterAWasSuppressed)
        #expect(!fastSWasSuppressed)
    }

    @Test func keyboardDebounceFilterSuppressesEarlyAutorepeatDuplicates() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let duplicateAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_020_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )
        let laterAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_060_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!firstAWasSuppressed)
        #expect(duplicateAWasSuppressed)
        #expect(!laterAWasSuppressed)
    }

    @Test func keyboardDebounceFilterAllowsHeldKeyRepeatEvents() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let firstRepeatAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_500_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )
        let nextRepeatAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_520_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!firstAWasSuppressed)
        #expect(!firstRepeatAWasSuppressed)
        #expect(!nextRepeatAWasSuppressed)

        filter.keyDidRelease(keyCode: 0)

        let nextPressAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_600_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!nextPressAWasSuppressed)
    }

    @Test func keyboardDebounceFilterAllowsFastRepressAfterRelease() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        _ = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        _ = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_500_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )

        filter.keyDidRelease(keyCode: 0)

        let nextPressAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_520_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!nextPressAWasSuppressed)
    }

    @Test func keyboardDebounceFilterAllowsDifferentKeysDuringRepeat() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let firstRepeatAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_500_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )
        let fastSWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 1,
            timestamp: 1_520_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!firstAWasSuppressed)
        #expect(!firstRepeatAWasSuppressed)
        #expect(!fastSWasSuppressed)
    }

    @Test func keyboardDebounceFilterAllowsLaterPressesAfterAutorepeatDuplicate() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let duplicateAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_020_000_000,
            isAutorepeat: true,
            debounceNanoseconds: debounceNanoseconds
        )
        let laterAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_060_000_000,
            debounceNanoseconds: debounceNanoseconds
        )

        #expect(!firstAWasSuppressed)
        #expect(duplicateAWasSuppressed)
        #expect(!laterAWasSuppressed)
    }

    @Test func keyboardDebounceFilterPersistsEnabledStateAndDebounceWindow() throws {
        let suiteName = "KeyboardDebounceFilterPersistenceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardDebounceEnabled = true
        manager.keyboardDebounceDelayMilliseconds = 30

        let reloadedManager = makeKeyboardManager(userDefaults: userDefaults)

        #expect(reloadedManager.keyboardDebounceEnabled)
        #expect(reloadedManager.keyboardDebounceDelayMilliseconds == 30)
    }

    @Test func keyboardDebounceFilterDebounceWindowIsClamped() throws {
        let suiteName = "KeyboardDebounceFilterClampTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)

        manager.keyboardDebounceDelayMilliseconds = 1
        #expect(manager.keyboardDebounceDelayMilliseconds == 5)

        manager.keyboardDebounceDelayMilliseconds = 250
        #expect(manager.keyboardDebounceDelayMilliseconds == 100)
    }

    @Test func mouseManagerAppliesPersistedDeviceSettingsWhenDevicesAreDetectedAfterInit() throws {
        let suiteName = "MouseManagerDetectedDeviceSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let persistedDevice = makeMouseDevice(
            naturalScrollEnabled: false,
            leftButtonEnabled: false,
            rightButtonEnabled: false,
            middleButtonEnabled: false,
            button4Enabled: false,
            button5Enabled: false,
            button4Action: .middleClick,
            button5Action: .none
        )
        let store = MouseDeviceStore(userDefaults: userDefaults)
        store.save([persistedDevice.id: persistedDevice])

        let manager = makeMouseManager(userDefaults: userDefaults)
        manager.setDetectedDevices([makeMouseDevice()])

        let detectedDevice = try #require(manager.connectedDevices.first)
        #expect(detectedDevice.id == persistedDevice.id)
        #expect(!detectedDevice.naturalScrollEnabled)
        #expect(!detectedDevice.leftButtonEnabled)
        #expect(!detectedDevice.rightButtonEnabled)
        #expect(!detectedDevice.middleButtonEnabled)
        #expect(!detectedDevice.button4Enabled)
        #expect(!detectedDevice.button5Enabled)
        #expect(detectedDevice.button4Action == .middleClick)
        #expect(detectedDevice.button5Action == .none)
    }

    @Test func mouseManagerKeepsPersistedDeviceSettingsAfterDisconnect() throws {
        let suiteName = "MouseManagerDisconnectedDeviceSettingsTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let device = makeMouseDevice()

        manager.addDevice(device)
        manager.updateButtonSettings(for: device.id, buttonType: .left, enabled: false)
        manager.updateButtonAction(for: device.id, buttonType: .button4, action: .middleClick)
        manager.removeDisconnectedDevices(currentDeviceIDs: [])

        #expect(manager.connectedDevices.isEmpty)

        manager.addDevice(device)

        let reconnectedDevice = try #require(manager.connectedDevices.first)
        #expect(!reconnectedDevice.leftButtonEnabled)
        #expect(reconnectedDevice.button4Action == .middleClick)

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        let persistedDevice = try #require(reloadedManager.deviceSettings[device.id])
        #expect(!persistedDevice.leftButtonEnabled)
        #expect(persistedDevice.button4Action == .middleClick)
    }

    @Test func cleanupRunResultComputedPropertiesSummarizeItems() {
        let moved = CleanupItem(url: URL(filePath: "/tmp/moved"), size: 10, modifiedDate: nil)
        let skipped = CleanupItem(url: URL(filePath: "/tmp/skipped"), size: 20, modifiedDate: nil)
        let emptyResult = CleanupRunResult(trashedItems: [], skippedItems: [])
        let result = CleanupRunResult(
            trashedItems: [moved],
            skippedItems: [
                CleanupSkippedItem(item: skipped, reason: "Nope")
            ]
        )

        #expect(!emptyResult.didTrashAnyItems)
        #expect(result.didTrashAnyItems)
        #expect(result.trashedBytes == 10)
        #expect(result.skippedBytes == 20)
        #expect(result.skippedItems.first?.id == skipped.url)
    }

    @Test func cleanupScanResultPreviewDetailsSummarizeCandidates() {
        let olderDate = Date(timeIntervalSince1970: 1_000)
        let newerDate = Date(timeIntervalSince1970: 2_000)
        let smallItem = CleanupItem(url: URL(filePath: "/tmp/small"), size: 10, modifiedDate: newerDate)
        let mediumItem = CleanupItem(url: URL(filePath: "/tmp/medium"), size: 20, modifiedDate: nil)
        let largeItem = CleanupItem(url: URL(filePath: "/tmp/large"), size: 30, modifiedDate: olderDate)
        let category = CleanupCategory(
            id: .temporaryFiles,
            title: "Temporary",
            subtitle: "Temporary fixtures",
            systemImage: "clock",
            paths: [URL(filePath: "/tmp")],
            riskLevel: .safe
        )
        let scanResult = CleanupScanResult(
            category: category,
            totalBytes: 60,
            itemCount: 3,
            items: [smallItem, mediumItem, largeItem]
        )

        #expect(scanResult.largestItem?.url == largeItem.url)
        #expect(scanResult.mostRecentModifiedDate == newerDate)
        #expect(scanResult.oldestModifiedDate == olderDate)
        #expect(scanResult.previewItems(limit: 2).map(\.url) == [largeItem.url, mediumItem.url])
    }

    @Test func cleanupModelIdentifiersAndRiskDescriptionsAreStable() {
        let item = CleanupItem(url: URL(filePath: "/tmp/model-item"), size: 1, modifiedDate: nil)
        let category = CleanupCategory(
            id: .logs,
            title: "Logs",
            subtitle: "Diagnostic logs",
            systemImage: "doc.text",
            paths: [URL(filePath: "/tmp/logs")],
            riskLevel: .review
        )
        let scanResult = CleanupScanResult(
            category: category,
            totalBytes: item.size,
            itemCount: 1,
            items: [item]
        )

        #expect(CleanupCategoryID.logs.id == "logs")
        #expect(CleanupRiskLevel.safe.description == "Usually safe to remove and commonly recreated by apps.")
        #expect(CleanupRiskLevel.review.description == "Worth reviewing before cleanup because contents can be useful.")
        #expect(item.id == item.url)
        #expect(scanResult.id == .logs)
    }
}

private func makeMouseDevice(
    id: String = "123-456-location-789",
    name: String = "Test Mouse",
    vendorID: Int = 123,
    productID: Int = 456,
    naturalScrollEnabled: Bool = true,
    leftButtonEnabled: Bool = true,
    rightButtonEnabled: Bool = true,
    middleButtonEnabled: Bool = true,
    button4Enabled: Bool = true,
    button5Enabled: Bool = true,
    button4Action: MouseButtonAction = .forward,
    button5Action: MouseButtonAction = .back
) -> MouseDevice {
    MouseDevice(
        id: id,
        name: name,
        vendorID: vendorID,
        productID: productID,
        naturalScrollEnabled: naturalScrollEnabled,
        lastConnected: Date(timeIntervalSince1970: 1_234),
        leftButtonEnabled: leftButtonEnabled,
        rightButtonEnabled: rightButtonEnabled,
        middleButtonEnabled: middleButtonEnabled,
        button4Enabled: button4Enabled,
        button5Enabled: button5Enabled,
        button4Action: button4Action,
        button5Action: button5Action
    )
}

private func makeMouseManager(userDefaults: UserDefaults) -> MouseManager {
    MouseManager(
        userDefaults: userDefaults,
        accessibilityManager: AccessibilityManager()
    )
}

private func makeKeyboardManager(userDefaults: UserDefaults) -> KeyboardManager {
    KeyboardManager(
        userDefaults: userDefaults,
        accessibilityManager: AccessibilityManager()
    )
}

private final class TrashRecorder: @unchecked Sendable {
    private(set) var urls: [URL] = []
    private let failingURLs: Set<URL>

    init(failingURLs: Set<URL> = []) {
        self.failingURLs = failingURLs
    }

    func record(_ url: URL) {
        urls.append(url)
    }

    func recordOrThrow(_ url: URL) throws {
        record(url)

        if failingURLs.contains(url) {
            throw TrashRecorderError(url: url)
        }
    }
}

private struct TrashRecorderError: LocalizedError {
    let url: URL

    var errorDescription: String? {
        "Trash failed for \(url.lastPathComponent)"
    }
}
