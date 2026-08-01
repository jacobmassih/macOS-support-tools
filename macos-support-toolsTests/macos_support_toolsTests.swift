import CoreGraphics
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
        #expect(result.items.first?.isDirectory == true)
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
        #expect(result.items.first?.isDirectory == false)
        #expect(result.totalBytes > 0)
    }

    @Test func cleanupScanTracksFilePathsAsNonDirectories() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let payloadURL = rootURL.appending(path: "payload.tmp")

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: payloadURL)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let category = CleanupCategory(
            id: .trash,
            title: "Test Trash",
            subtitle: "Fixture category",
            systemImage: "trash",
            paths: [payloadURL],
            riskLevel: .review
        )

        let result = try CleanupManager.scan(category: category)

        #expect(result.itemCount == 1)
        #expect(result.items.first?.url.resolvingSymlinksInPath() == payloadURL.resolvingSymlinksInPath())
        #expect(result.items.first?.modifiedDate != nil)
        #expect(result.items.first?.isDirectory == false)
        #expect(result.totalBytes > 0)
    }

    @Test @MainActor func cleanupCandidateRowsUseStoredDirectoryMetadata() {
        let folderItem = CleanupItem(
            url: URL(filePath: "/tmp/CleanupFixture"),
            size: 1,
            modifiedDate: nil,
            isDirectory: true
        )
        let fileItem = CleanupItem(
            url: URL(filePath: "/tmp/CleanupFixture.log"),
            size: 1,
            modifiedDate: nil,
            isDirectory: false
        )

        _ = CleanupCandidateRow(item: folderItem).body
        _ = CleanupCandidateRow(item: fileItem).body
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

        manager.naturalScrollEnabled = false
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
        manager.updateButtonSettings(for: device.id, buttonType: .button4, enabled: false)
        manager.updateButtonSettings(for: device.id, buttonType: .button5, enabled: false)
        manager.updateButtonAction(for: device.id, buttonType: .button4, action: .middleClick)
        manager.updateButtonAction(for: device.id, buttonType: .button5, action: .none)
        manager.mouseButtonsEnabled = false

        let updatedDevice = try #require(manager.deviceSettings[device.id])
        #expect(!updatedDevice.button4Enabled)
        #expect(!updatedDevice.button5Enabled)
        #expect(updatedDevice.button4Action == .middleClick)
        #expect(updatedDevice.button5Action == .none)
        #expect(!manager.mouseButtonsEnabled)
        #expect(!userDefaults.bool(forKey: MouseManager.DefaultsKey.mouseButtonsEnabled))

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        let reloadedDevice = try #require(reloadedManager.deviceSettings[device.id])
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

    @Test func keyboardDebounceFilterAllowsAutorepeatEvents() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let repeatAWasSuppressed = filter.shouldSuppressKeyDown(
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
        #expect(!repeatAWasSuppressed)
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

    @Test func keyboardDebounceFilterAllowsLaterPressesAfterAutorepeat() throws {
        var filter = KeyboardDebounceFilter()
        let debounceNanoseconds: UInt64 = 45_000_000

        let firstAWasSuppressed = filter.shouldSuppressKeyDown(
            keyCode: 0,
            timestamp: 1_000_000_000,
            debounceNanoseconds: debounceNanoseconds
        )
        let repeatAWasSuppressed = filter.shouldSuppressKeyDown(
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
        #expect(!repeatAWasSuppressed)
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
        #expect(!detectedDevice.button4Enabled)
        #expect(!detectedDevice.button5Enabled)
        #expect(detectedDevice.button4Action == .middleClick)
        #expect(detectedDevice.button5Action == .none)
    }

    @Test func mouseManagerAllowsButtonConfigurationForNewDevicesDetectedAtLaunch() throws {
        let suiteName = "MouseManagerLaunchDetectedDeviceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let device = makeMouseDevice()

        // Initial detection at launch is the only path that populates
        // connectedDevices without going through addDevice.
        manager.setDetectedDevices([device])

        #expect(manager.deviceSettings[device.id] != nil)

        manager.updateButtonSettings(for: device.id, buttonType: .button4, enabled: false)
        manager.updateButtonAction(for: device.id, buttonType: .button5, action: .middleClick)

        let updatedDevice = try #require(manager.deviceSettings[device.id])
        #expect(!updatedDevice.button4Enabled)
        #expect(updatedDevice.button5Action == .middleClick)

        let connectedDevice = try #require(manager.connectedDevices.first)
        #expect(!connectedDevice.button4Enabled)
        #expect(connectedDevice.button5Action == .middleClick)

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        let persistedDevice = try #require(reloadedManager.deviceSettings[device.id])
        #expect(!persistedDevice.button4Enabled)
        #expect(persistedDevice.button5Action == .middleClick)
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
        manager.addDevice(makeMouseDevice(id: "999-888-location-777"))
        manager.updateButtonSettings(for: device.id, buttonType: .button5, enabled: false)
        manager.updateButtonAction(for: device.id, buttonType: .button4, action: .middleClick)
        manager.removeDevice(withID: "999-888-location-777")

        #expect(manager.connectedDevices.map(\.id) == [device.id])

        manager.removeDevice(withID: device.id)

        #expect(manager.connectedDevices.isEmpty)

        manager.addDevice(device)

        let reconnectedDevice = try #require(manager.connectedDevices.first)
        #expect(!reconnectedDevice.button5Enabled)
        #expect(reconnectedDevice.button4Action == .middleClick)

        let reloadedManager = makeMouseManager(userDefaults: userDefaults)
        let persistedDevice = try #require(reloadedManager.deviceSettings[device.id])
        #expect(!persistedDevice.button5Enabled)
        #expect(persistedDevice.button4Action == .middleClick)
    }

    @Test func mouseManagerRemoveDeviceByIDDropsMatchingDeviceAndIgnoresUnknownID() throws {
        let suiteName = "MouseManagerRemoveDeviceByIDTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let device = makeMouseDevice()
        manager.addDevice(device)

        // Removing an ID that was never added is a no-op.
        manager.removeDevice(withID: "not-a-connected-device")
        #expect(manager.connectedDevices.map(\.id) == [device.id])
        #expect(manager.isAnyExternalMouseConnected)

        manager.removeDevice(withID: device.id)
        #expect(manager.connectedDevices.isEmpty)
        #expect(!manager.isAnyExternalMouseConnected)
    }

    @Test func scrollReversalPolicyReversesDiscreteWheelDeltas() {
        let descriptor = makeScrollEventDescriptor(vertical: 3, horizontal: -2)

        let reversal = ScrollReversalPolicy.reversal(for: descriptor)

        #expect(reversal?.deltas == ScrollWheelDeltas(vertical: -3, horizontal: 2))
        #expect(reversal?.pointDeltas == nil)
    }

    @Test func scrollReversalPolicyReversesPointDeltasWhenPresent() {
        let descriptor = makeScrollEventDescriptor(
            vertical: 1,
            horizontal: 0,
            pointVertical: 10,
            pointHorizontal: -4
        )

        let reversal = ScrollReversalPolicy.reversal(for: descriptor)

        #expect(reversal?.deltas == ScrollWheelDeltas(vertical: -1, horizontal: 0))
        #expect(reversal?.pointDeltas == ScrollWheelDeltas(vertical: -10, horizontal: 4))
    }

    @Test func scrollReversalPolicySkipsTrackpadPhases() {
        let scrollPhase = makeScrollEventDescriptor(vertical: 3, horizontal: 0, scrollPhase: 1)
        let momentumPhase = makeScrollEventDescriptor(vertical: 3, horizontal: 0, momentumPhase: 1)

        #expect(ScrollReversalPolicy.reversal(for: scrollPhase) == nil)
        #expect(ScrollReversalPolicy.reversal(for: momentumPhase) == nil)
    }

    @Test func scrollReversalPolicySkipsSubWheelSizedDeltas() {
        // Whole-number, but smaller than one wheel click.
        let tinyDelta = makeScrollEventDescriptor(vertical: 0, horizontal: 0)

        #expect(ScrollReversalPolicy.reversal(for: tinyDelta) == nil)
    }

    @Test func scrollReversalPolicySkipsFractionalTrackpadDeltas() {
        let fractional = makeScrollEventDescriptor(vertical: 3.5, horizontal: 2.25)

        #expect(ScrollReversalPolicy.reversal(for: fractional) == nil)
    }

    @Test func scrollEventDescriptorReadsVerticalDeltaFromAxis1() throws {
        let event = try #require(makeScrollEvent(axis1: 3, axis2: -2))

        let descriptor = event.scrollEventDescriptor

        #expect(descriptor.deltas == ScrollWheelDeltas(vertical: 3, horizontal: -2))
    }

    @Test func reverseScrollIfNeededFlipsWheelEventInPlace() throws {
        let event = try #require(makeScrollEvent(axis1: 3, axis2: -2))

        reverseScrollIfNeeded(event)

        #expect(event.getDoubleValueField(.scrollWheelEventDeltaAxis1) == -3)
        #expect(event.getDoubleValueField(.scrollWheelEventDeltaAxis2) == 2)
    }

    @Test func reverseScrollIfNeededSkipsPointDeltasWhenEventCarriesNone() throws {
        let event = try #require(makeScrollEvent(axis1: 3, axis2: 0))
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: 0)
        #expect(event.scrollEventDescriptor.pointDeltas.isZero)

        reverseScrollIfNeeded(event)

        // CoreGraphics re-derives the point deltas from the line deltas, so only
        // the line deltas are ours to assert on here.
        #expect(event.getDoubleValueField(.scrollWheelEventDeltaAxis1) == -3)
    }

    @Test func reverseScrollIfNeededLeavesTrackpadEventUntouched() throws {
        let event = try #require(makeScrollEvent(axis1: 3, axis2: 0))
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)

        reverseScrollIfNeeded(event)

        #expect(event.getDoubleValueField(.scrollWheelEventDeltaAxis1) == 3)
    }

    @Test func keyboardManagerSuppressesEveryEventWhileBlocked() throws {
        let suiteName = "KeyboardManagerBlockedTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardBlocked = true
        let event = try #require(makeKeyboardEvent(keyDown: false))

        #expect(manager.shouldSuppressKeyboardEvent(event, type: .keyUp))
    }

    @Test func keyboardManagerAllowsEventsWhenDebounceDisabled() throws {
        let suiteName = "KeyboardManagerDebounceOffTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        let event = try #require(makeKeyboardEvent(keyDown: true))

        #expect(!manager.shouldSuppressKeyboardEvent(event, type: .keyDown))
    }

    @Test func keyboardManagerDebouncesRepeatedKeyDownsButIgnoresKeyUps() throws {
        let suiteName = "KeyboardManagerDebounceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardDebounceEnabled = true
        manager.keyboardDebounceDelayMilliseconds = 45

        let firstPress = try #require(makeKeyboardEvent(keyDown: true, timestamp: 1_000_000_000))
        #expect(!manager.shouldSuppressKeyboardEvent(firstPress, type: .keyDown))

        // A key up never consults the debounce filter, even inside the window.
        let release = try #require(makeKeyboardEvent(keyDown: false, timestamp: 1_005_000_000))
        #expect(!manager.shouldSuppressKeyboardEvent(release, type: .keyUp))

        // A second press 10ms later is chatter and gets suppressed.
        let bounce = try #require(makeKeyboardEvent(keyDown: true, timestamp: 1_010_000_000))
        #expect(manager.shouldSuppressKeyboardEvent(bounce, type: .keyDown))
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

    @Test func tapDisabledEventTypesAreRecognized() {
        #expect(CGEventType.tapDisabledByTimeout.isTapDisabledEvent)
        #expect(CGEventType.tapDisabledByUserInput.isTapDisabledEvent)
        #expect(!CGEventType.scrollWheel.isTapDisabledEvent)
        #expect(!CGEventType.otherMouseDown.isTapDisabledEvent)
        #expect(!CGEventType.keyDown.isTapDisabledEvent)
    }

    @Test func mouseEventCallbacksPassThroughTapDisabledNotifications() throws {
        let suiteName = "MouseTapDisabledTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeMouseManager(userDefaults: userDefaults)
        let scrollEvent = try #require(CGEvent(source: nil))
        let buttonEvent = try #require(CGEvent(source: nil))

        let scrollResult = try invokeTapCallback(
            scrollEventCallback,
            refconObject: manager,
            type: .tapDisabledByTimeout,
            event: scrollEvent
        )
        let buttonResult = try invokeTapCallback(
            buttonEventCallback,
            refconObject: manager,
            type: .tapDisabledByUserInput,
            event: buttonEvent
        )

        #expect(scrollResult === scrollEvent)
        #expect(buttonResult === buttonEvent)
    }

    @Test func keyboardEventCallbackPassesThroughTimeoutNotificationsWhileBlocking() throws {
        let suiteName = "KeyboardTapDisabledTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardBlocked = true

        let disabledNotification = try #require(CGEvent(source: nil))
        let notificationResult = try invokeTapCallback(
            keyboardEventCallback,
            refconObject: manager,
            type: .tapDisabledByTimeout,
            event: disabledNotification
        )
        #expect(notificationResult === disabledNotification)

        // A stall is not a user request: the block stays on.
        #expect(manager.keyboardBlocked)

        let keyDownEvent = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        let keyDownResult = try invokeTapCallback(
            keyboardEventCallback,
            refconObject: manager,
            type: .keyDown,
            event: keyDownEvent
        )
        #expect(keyDownResult == nil)
    }

    @Test func keyboardTapDisabledByUserInputReleasesKeyboardBlock() async throws {
        let suiteName = "KeyboardUserInputDisableTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardBlocked = true

        let notification = try #require(CGEvent(source: nil))
        let result = try invokeTapCallback(
            keyboardEventCallback,
            refconObject: manager,
            type: .tapDisabledByUserInput,
            event: notification
        )
        #expect(result === notification)

        // The release is hopped off the tap callback, so drain the main queue.
        await MainActor.run {}

        // The OS-level escape from Block Keyboard must actually unblock it,
        // otherwise the toggle claims to be blocking a keyboard that works.
        #expect(!manager.keyboardBlocked)

        let keyDownEvent = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        let keyDownResult = try invokeTapCallback(
            keyboardEventCallback,
            refconObject: manager,
            type: .keyDown,
            event: keyDownEvent
        )
        #expect(keyDownResult === keyDownEvent)
    }

    @Test func keyboardTapDisabledByUserInputWithoutBlockingKeepsDebounceAlive() throws {
        let suiteName = "KeyboardUserInputDebounceTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let manager = makeKeyboardManager(userDefaults: userDefaults)
        manager.keyboardDebounceEnabled = true

        let notification = try #require(CGEvent(source: nil))
        let result = try invokeTapCallback(
            keyboardEventCallback,
            refconObject: manager,
            type: .tapDisabledByUserInput,
            event: notification
        )

        // Debounce is not a lockout, so there is no escape to honour here.
        #expect(result === notification)
        #expect(!manager.keyboardBlocked)
        #expect(manager.keyboardDebounceEnabled)
    }

    @Test func mouseButtonActionRoundTripsRemainingCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for action in MouseButtonAction.allCases {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(MouseButtonAction.self, from: data)
            #expect(decoded == action)
        }
    }
}

private func makeMouseDevice(
    id: String = "123-456-location-789",
    name: String = "Test Mouse",
    vendorID: Int = 123,
    productID: Int = 456,
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
        button4Enabled: button4Enabled,
        button5Enabled: button5Enabled,
        button4Action: button4Action,
        button5Action: button5Action
    )
}

private func makeScrollEventDescriptor(
    vertical: Double,
    horizontal: Double,
    pointVertical: Double = 0,
    pointHorizontal: Double = 0,
    scrollPhase: Int64 = 0,
    momentumPhase: Int64 = 0
) -> ScrollEventDescriptor {
    ScrollEventDescriptor(
        deltas: ScrollWheelDeltas(vertical: vertical, horizontal: horizontal),
        pointDeltas: ScrollWheelDeltas(vertical: pointVertical, horizontal: pointHorizontal),
        scrollPhase: scrollPhase,
        momentumPhase: momentumPhase
    )
}

private func makeScrollEvent(axis1: Double, axis2: Double) -> CGEvent? {
    guard let event = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .line,
        wheelCount: 2,
        wheel1: 0,
        wheel2: 0,
        wheel3: 0
    ) else {
        return nil
    }

    event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: axis1)
    event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: axis2)
    return event
}

private func makeKeyboardEvent(
    keyDown: Bool,
    keyCode: CGKeyCode = 0,
    timestamp: CGEventTimestamp? = nil
) -> CGEvent? {
    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
        return nil
    }

    if let timestamp {
        event.timestamp = timestamp
    }

    return event
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

private func invokeTapCallback(
    _ callback: (CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?,
    refconObject: AnyObject,
    type: CGEventType,
    event: CGEvent
) throws -> CGEvent? {
    // #require rather than a nil-returning guard: the callbacks under test return
    // nil to mean "event suppressed", so a helper that also returns nil on setup
    // failure would let those assertions pass for the wrong reason.
    let proxy = try #require(OpaquePointer(bitPattern: 1))

    let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(refconObject).toOpaque())
    return callback(proxy, type, event, refcon)?.takeRetainedValue()
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
