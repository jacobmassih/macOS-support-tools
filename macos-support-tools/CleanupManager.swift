//
//  CleanupManager.swift
//  macos-support-tools
//
//  Created by Codex on 2026-06-04.
//

import Foundation
import Observation

@Observable
final class CleanupManager {
    private(set) var isScanning = false
    private(set) var scanResults: [CleanupScanResult] = []
    private(set) var lastScanDate: Date?
    private(set) var lastError: String?
    
    var totalReclaimableBytes: Int64 {
        scanResults.reduce(0) { $0 + $1.totalBytes }
    }
    
    var categories: [CleanupCategory] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        
        return [
            CleanupCategory(
                id: .userCaches,
                title: "User Caches",
                subtitle: "App cache files in your user Library. Apps may recreate these after cleanup.",
                systemImage: "shippingbox",
                paths: [
                    homeDirectory.appending(path: "Library/Caches", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .temporaryFiles,
                title: "Temporary Files",
                subtitle: "Short-lived files from macOS and apps.",
                systemImage: "clock.arrow.circlepath",
                paths: [
                    URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory),
                    URL(filePath: "/private/tmp", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .xcodeDerivedData,
                title: "Xcode DerivedData",
                subtitle: "Build intermediates that Xcode can regenerate.",
                systemImage: "hammer",
                paths: [
                    homeDirectory.appending(path: "Library/Developer/Xcode/DerivedData", directoryHint: .isDirectory)
                ],
                riskLevel: .safe
            ),
            CleanupCategory(
                id: .logs,
                title: "Logs",
                subtitle: "User diagnostic logs. Recent logs can help troubleshoot apps.",
                systemImage: "doc.text.magnifyingglass",
                paths: [
                    homeDirectory.appending(path: "Library/Logs", directoryHint: .isDirectory)
                ],
                riskLevel: .review
            ),
            CleanupCategory(
                id: .trash,
                title: "Trash",
                subtitle: "Items already moved to Trash. Phase 1 only reports size.",
                systemImage: "trash",
                paths: [
                    homeDirectory.appending(path: ".Trash", directoryHint: .isDirectory)
                ],
                riskLevel: .review
            )
        ]
    }
    
    @MainActor
    func scan() async {
        isScanning = true
        lastError = nil
        
        let categoriesToScan = categories
        
        do {
            let results = try await Task.detached(priority: .userInitiated) {
                try categoriesToScan.map { category in
                    try Self.scan(category: category)
                }
            }.value
            
            scanResults = results
            lastScanDate = Date()
        } catch {
            lastError = error.localizedDescription
        }
        
        isScanning = false
    }
    
    nonisolated private static func scan(category: CleanupCategory) throws -> CleanupScanResult {
        let items = category.paths.flatMap { path -> [CleanupItem] in
            guard FileManager.default.fileExists(atPath: path.path) else {
                return []
            }
            
            return cleanupItems(in: path)
        }
        .sorted { $0.size > $1.size }
        
        return CleanupScanResult(
            category: category,
            totalBytes: items.reduce(0) { $0 + $1.size },
            itemCount: items.count,
            items: items
        )
    }
    
    nonisolated private static func cleanupItems(in directoryURL: URL) -> [CleanupItem] {
        guard let childURLs = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .isRegularFileKey],
            options: []
        ) else {
            return [
                CleanupItem(
                    url: directoryURL,
                    size: folderSize(at: directoryURL),
                    modifiedDate: modifiedDate(for: directoryURL)
                )
            ]
        }
        
        return childURLs.map { url in
            CleanupItem(
                url: url,
                size: folderSize(at: url),
                modifiedDate: modifiedDate(for: url)
            )
        }
    }
    
    nonisolated private static func folderSize(at url: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return fileSize(at: url)
        }
        
        var totalBytes: Int64 = fileSize(at: url)
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }
            
            if values.isRegularFile == true {
                totalBytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        
        return totalBytes
    }
    
    nonisolated private static func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return 0
        }
        
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
    
    nonisolated private static func modifiedDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
