import Foundation

final class LayoutMerger {
    func merge(
        saved: LayoutDocument?,
        applications: [InstalledApplication]
    ) -> LayoutSnapshot {
        let applicationsByKey = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.identity.stableKey, $0) }
        )

        let document: LayoutDocument
        if let saved, (1...LayoutDocument.currentVersion).contains(saved.version) {
            document = saved.isCustomized
                ? mergeSaved(saved, applicationsByKey: applicationsByKey)
                : makeDefault(applications, shortcut: saved.shortcut)
        } else {
            document = makeDefault(applications)
        }

        return LayoutSnapshot(document: document, applicationsByKey: applicationsByKey)
    }

    func makeDefault(
        _ applications: [InstalledApplication],
        shortcut: HotKeyConfiguration = .defaultConfiguration
    ) -> LayoutDocument {
        let systems = applications.filter(\.isSystemApplication)
        let users = applications.filter { !$0.isSystemApplication }.sorted(by: userOrder)
        var remainingSystems = Dictionary(
            uniqueKeysWithValues: systems.map { ($0.identity.stableKey, $0) }
        )
        let systemsByBundle = Dictionary(
            systems.compactMap { application in
                application.identity.bundleIdentifier.map { ($0.lowercased(), application) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        var items: [LayoutItem] = []
        for bundleIdentifier in DefaultApplicationOrder.primaryBundleIdentifiers {
            guard let application = systemsByBundle[bundleIdentifier.lowercased()] else { continue }
            items.append(.application(application.identity))
            remainingSystems.removeValue(forKey: application.identity.stableKey)
        }

        var utilities: [ApplicationIdentity] = []
        for bundleIdentifier in DefaultApplicationOrder.utilityBundleIdentifiers {
            guard let application = systemsByBundle[bundleIdentifier.lowercased()] else { continue }
            utilities.append(application.identity)
            remainingSystems.removeValue(forKey: application.identity.stableKey)
        }
        if !utilities.isEmpty {
            items.append(.folder(FolderLayout(
                id: UUID(),
                name: DefaultApplicationOrder.utilitiesFolderName,
                applications: utilities
            )))
        }

        let unlistedSystems = remainingSystems.values.sorted(by: stableNameOrder)
        items.append(contentsOf: unlistedSystems.map { .application($0.identity) })
        items.append(contentsOf: users.map { .application($0.identity) })
        return LayoutDocument(items: items, shortcut: shortcut)
    }

    private func mergeSaved(
        _ saved: LayoutDocument,
        applicationsByKey: [String: InstalledApplication]
    ) -> LayoutDocument {
        var seen = Set<String>()
        var items: [LayoutItem] = []

        for item in saved.items {
            switch item {
            case .application(let identity):
                guard let application = applicationsByKey[identity.stableKey] else { continue }
                guard seen.insert(application.identity.stableKey).inserted else { continue }
                items.append(.application(application.identity))

            case .folder(var folder):
                folder.applications = folder.applications.compactMap { identity in
                    guard
                        let application = applicationsByKey[identity.stableKey],
                        seen.insert(application.identity.stableKey).inserted
                    else {
                        return nil
                    }
                    return application.identity
                }
                if folder.applications.count >= 2 {
                    items.append(.folder(folder))
                } else if let onlyApplication = folder.applications.first {
                    items.append(.application(onlyApplication))
                }
            }
        }

        let newApplications = applicationsByKey.values.filter {
            !seen.contains($0.identity.stableKey)
        }
        let newSystems = newApplications.filter(\.isSystemApplication).sorted(by: stableNameOrder)
        let newUsers = newApplications.filter { !$0.isSystemApplication }.sorted(by: userOrder)
        let insertionIndex = items.firstIndex { item in
            item.applicationIdentities.contains { identity in
                applicationsByKey[identity.stableKey]?.isSystemApplication == false
            }
        } ?? items.endIndex
        items.insert(contentsOf: newSystems.map { .application($0.identity) }, at: insertionIndex)
        items.append(contentsOf: newUsers.map { .application($0.identity) })
        return LayoutDocument(items: items, isCustomized: true, shortcut: saved.shortcut)
    }

    private func userOrder(_ lhs: InstalledApplication, _ rhs: InstalledApplication) -> Bool {
        if lhs.dateAdded != rhs.dateAdded {
            return lhs.dateAdded < rhs.dateAdded
        }
        return stableNameOrder(lhs, rhs)
    }

    private func stableNameOrder(_ lhs: InstalledApplication, _ rhs: InstalledApplication) -> Bool {
        let comparison = lhs.displayName.localizedStandardCompare(rhs.displayName)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.identity.stableKey < rhs.identity.stableKey
    }
}
