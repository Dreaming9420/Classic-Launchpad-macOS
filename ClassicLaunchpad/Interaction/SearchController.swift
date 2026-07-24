import Foundation

final class SearchController {
    func filteredSnapshot(from snapshot: LayoutSnapshot, query: String) -> LayoutSnapshot {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return snapshot }

        var seen = Set<String>()
        let identities = snapshot.document.items
            .flatMap(\.applicationIdentities)
            .filter { identity in
                guard
                    seen.insert(identity.stableKey).inserted,
                    let application = snapshot.application(for: identity)
                else {
                    return false
                }
                return normalize(application.displayName).contains(normalizedQuery)
                    || normalize(application.identity.bundleIdentifier ?? "").contains(normalizedQuery)
            }
        return LayoutSnapshot(
            document: LayoutDocument(
                items: identities.map(LayoutItem.application),
                sortMode: snapshot.document.sortMode,
                shortcut: snapshot.document.shortcut
            ),
            applicationsByKey: snapshot.applicationsByKey
        )
    }

    private func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
