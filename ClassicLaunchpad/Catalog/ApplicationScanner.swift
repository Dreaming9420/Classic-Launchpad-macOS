import Foundation
import CoreServices
import OSLog

final class ApplicationScanner {
    private static let knownSystemBundleIdentifiers = Set(
        DefaultApplicationOrder.primaryBundleIdentifiers
            + DefaultApplicationOrder.utilityBundleIdentifiers
    )

    private enum BundleKey {
        static let packageType = "CFBundlePackageType"
        static let applicationPackageType = "APPL"
        static let backgroundOnly = "LSBackgroundOnly"
        static let shortVersion = "CFBundleShortVersionString"
        static let buildVersion = "CFBundleVersion"
    }

    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "ApplicationScanner"
    )

    private let fileManager = FileManager.default
    private let nameResolver = ApplicationNameResolver()

    func scanStandardLocations(additionalURLs: [URL] = []) async -> [InstalledApplication] {
        await Task.detached(priority: .userInitiated) { [self] in
            var urls = additionalURLs.filter(ApplicationLocation.containsUserVisibleApplication)
            for root in ApplicationLocation.scanRoots where fileManager.fileExists(atPath: root.path) {
                urls.append(contentsOf: applicationURLs(in: root))
            }
            return inspectSynchronously(urls: urls)
        }.value
    }

    func inspect(urls: [URL]) async -> [InstalledApplication] {
        await Task.detached(priority: .userInitiated) { [self] in
            inspectSynchronously(urls: urls)
        }.value
    }

    private func applicationURLs(in root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants],
            errorHandler: { url, error in
                Self.logger.error(
                    "Unable to inspect an application directory: \(error.localizedDescription, privacy: .public); item=\(url.lastPathComponent, privacy: .private(mask: .hash))"
                )
                return true
            }
        ) else {
            return []
        }

        var results: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
            results.append(url)
            enumerator.skipDescendants()
        }
        return results
    }

    private func inspectSynchronously(urls: [URL]) -> [InstalledApplication] {
        var byIdentity: [String: InstalledApplication] = [:]

        for sourceURL in Set(urls) {
            autoreleasepool {
                guard let application = application(at: sourceURL) else { return }
                let key = application.identity.stableKey
                if let existing = byIdentity[key] {
                    byIdentity[key] = preferred(existing, application)
                } else {
                    byIdentity[key] = application
                }
            }
        }

        return Array(byIdentity.values)
    }

    private func application(at sourceURL: URL) -> InstalledApplication? {
        let url = sourceURL.standardizedFileURL
        guard
            ApplicationLocation.containsUserVisibleApplication(url),
            url.pathExtension.lowercased() == "app",
            !isNestedApplication(url)
        else {
            return nil
        }
        guard fileManager.fileExists(atPath: url.path), let bundle = Bundle(url: url) else { return nil }

        let info = bundle.infoDictionary ?? [:]
        guard (info[BundleKey.packageType] as? String) == BundleKey.applicationPackageType else { return nil }
        guard !booleanValue(info[BundleKey.backgroundOnly]) else { return nil }
        guard bundle.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        guard let executableURL = bundle.executableURL, fileManager.isExecutableFile(atPath: executableURL.path) else {
            Self.logger.notice(
                "Skipped an application with no executable; item=\(url.lastPathComponent, privacy: .private(mask: .hash))"
            )
            return nil
        }

        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let spotlight = spotlightMetadata(for: url)
        let dateAdded = spotlight.dateAdded ?? values?.creationDate ?? values?.contentModificationDate ?? .distantPast
        let modificationTime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let shortVersion = info[BundleKey.shortVersion] as? String ?? ""
        let buildVersion = info[BundleKey.buildVersion] as? String ?? ""
        let path = url.path
        let identity = ApplicationIdentity(
            bundleIdentifier: bundle.bundleIdentifier,
            normalizedPath: path
        )
        let isSystemPath = path == ApplicationLocation.systemApplications.path
            || path.hasPrefix(ApplicationLocation.systemApplications.path + "/")
        let isKnownSystemBundle = bundle.bundleIdentifier.map(Self.knownSystemBundleIdentifiers.contains) ?? false
        let isSystem = isSystemPath || isKnownSystemBundle
        let receipt = url
            .appendingPathComponent("Contents/_MASReceipt/receipt", isDirectory: false)
        let canMoveToTrash = !isSystem
            && fileManager.fileExists(atPath: receipt.path)
            && isInsideUserApplicationLocation(url)

        return InstalledApplication(
            identity: identity,
            displayName: nameResolver.displayName(
                for: bundle,
                url: url,
                metadataDisplayName: spotlight.displayName
            ),
            url: url,
            isSystemApplication: isSystem,
            dateAdded: dateAdded,
            versionFingerprint: "\(shortVersion)|\(buildVersion)|\(modificationTime)",
            canMoveToTrash: canMoveToTrash
        )
    }

    private func isNestedApplication(_ url: URL) -> Bool {
        url.deletingLastPathComponent().pathComponents.contains { component in
            component.lowercased().hasSuffix(".app")
        }
    }

    private func isInsideUserApplicationLocation(_ url: URL) -> Bool {
        let path = url.path
        let localRoot = ApplicationLocation.localApplications.path + "/"
        let userRoot = ApplicationLocation.userApplications.path + "/"
        return path.hasPrefix(localRoot) || path.hasPrefix(userRoot)
    }

    private func booleanValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return NSString(string: string).boolValue }
        return false
    }

    private func spotlightMetadata(for url: URL) -> (dateAdded: Date?, displayName: String?) {
        guard let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString) else {
            return (nil, nil)
        }
        let dateAdded = MDItemCopyAttribute(item, kMDItemDateAdded) as? Date
        let displayName = MDItemCopyAttribute(item, kMDItemDisplayName) as? String
        return (dateAdded, displayName)
    }

    private func preferred(
        _ first: InstalledApplication,
        _ second: InstalledApplication
    ) -> InstalledApplication {
        let firstRank = locationRank(first.url)
        let secondRank = locationRank(second.url)
        if firstRank != secondRank {
            return firstRank < secondRank ? first : second
        }
        if first.dateAdded != second.dateAdded {
            return first.dateAdded > second.dateAdded ? first : second
        }
        return first.identity.normalizedPath.localizedStandardCompare(second.identity.normalizedPath) == .orderedAscending
            ? first
            : second
    }

    private func locationRank(_ url: URL) -> Int {
        let path = url.path
        if path.hasPrefix(ApplicationLocation.systemApplications.path + "/") { return 0 }
        if path.hasPrefix(ApplicationLocation.localApplications.path + "/") { return 1 }
        if path.hasPrefix(ApplicationLocation.userApplications.path + "/") { return 2 }
        if path.hasPrefix(ApplicationLocation.networkApplications.path + "/") { return 3 }
        return 4
    }
}
