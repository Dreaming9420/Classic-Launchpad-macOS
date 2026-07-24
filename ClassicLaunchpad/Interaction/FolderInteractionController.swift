import Foundation

final class FolderInteractionController {
    func drop(
        draggedStableID: String,
        onto targetStableID: String,
        in document: LayoutDocument
    ) -> LayoutDocument? {
        guard draggedStableID != targetStableID else { return nil }
        var items = document.items
        guard
            let draggedIndex = items.firstIndex(where: { $0.stableID == draggedStableID }),
            let targetIndex = items.firstIndex(where: { $0.stableID == targetStableID })
        else {
            return nil
        }
        guard case .application(let draggedIdentity) = items[draggedIndex] else { return nil }

        switch items[targetIndex] {
        case .application(let targetIdentity):
            let folder = FolderLayout(
                id: UUID(),
                name: DefaultFolderName.value,
                applications: [targetIdentity, draggedIdentity]
            )
            let lowerIndex = min(draggedIndex, targetIndex)
            let upperIndex = max(draggedIndex, targetIndex)
            items.remove(at: upperIndex)
            items.remove(at: lowerIndex)
            items.insert(.folder(folder), at: lowerIndex)

        case .folder(var folder):
            guard !folder.applications.contains(where: { $0.stableKey == draggedIdentity.stableKey }) else {
                return nil
            }
            items.remove(at: draggedIndex)
            let adjustedTarget = draggedIndex < targetIndex ? targetIndex - 1 : targetIndex
            folder.applications.append(draggedIdentity)
            items[adjustedTarget] = .folder(folder)
        }
        return LayoutDocument(items: items, sortMode: .custom, shortcut: document.shortcut)
    }

    func rename(folderID: UUID, name: String, in document: LayoutDocument) -> LayoutDocument {
        var items = document.items
        guard let index = items.firstIndex(where: {
            if case .folder(let folder) = $0 { return folder.id == folderID }
            return false
        }), case .folder(var folder) = items[index] else {
            return document
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folder.name = trimmed.isEmpty ? DefaultFolderName.value : trimmed
        items[index] = .folder(folder)
        return LayoutDocument(items: items, sortMode: .custom, shortcut: document.shortcut)
    }

    func extract(
        identity: ApplicationIdentity,
        from folderID: UUID,
        in document: LayoutDocument
    ) -> LayoutDocument? {
        var items = document.items
        guard let index = items.firstIndex(where: {
            if case .folder(let folder) = $0 { return folder.id == folderID }
            return false
        }), case .folder(var folder) = items[index],
              folder.applications.contains(where: { $0.stableKey == identity.stableKey }) else {
            return nil
        }
        folder.applications.removeAll { $0.stableKey == identity.stableKey }
        if folder.applications.count >= 2 {
            items[index] = .folder(folder)
        } else {
            items.remove(at: index)
            if let remaining = folder.applications.first {
                items.insert(.application(remaining), at: index)
            }
        }
        items.insert(.application(identity), at: min(index + 1, items.count))
        return LayoutDocument(items: items, sortMode: .custom, shortcut: document.shortcut)
    }

    func reorder(
        applications: [ApplicationIdentity],
        in folderID: UUID,
        document: LayoutDocument
    ) -> LayoutDocument? {
        var items = document.items
        guard let index = items.firstIndex(where: {
            if case .folder(let folder) = $0 { return folder.id == folderID }
            return false
        }), case .folder(var folder) = items[index] else {
            return nil
        }
        let currentKeys = folder.applications.map(\.stableKey)
        let reorderedKeys = applications.map(\.stableKey)
        guard currentKeys.count == reorderedKeys.count,
              Set(currentKeys) == Set(reorderedKeys) else {
            return nil
        }
        folder.applications = applications
        items[index] = .folder(folder)
        return LayoutDocument(items: items, sortMode: .custom, shortcut: document.shortcut)
    }
}

private enum DefaultFolderName {
    static let value = "文件夹"
}
