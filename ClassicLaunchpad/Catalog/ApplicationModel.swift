import Foundation

struct ApplicationIdentity: Codable, Hashable {
    let bundleIdentifier: String?
    let normalizedPath: String

    var stableKey: String {
        bundleIdentifier?.lowercased() ?? normalizedPath.lowercased()
    }
}

struct InstalledApplication: Hashable {
    let identity: ApplicationIdentity
    let displayName: String
    let url: URL
    let isSystemApplication: Bool
    let dateAdded: Date
    let versionFingerprint: String
    let canMoveToTrash: Bool

    static func == (lhs: InstalledApplication, rhs: InstalledApplication) -> Bool {
        lhs.identity == rhs.identity && lhs.versionFingerprint == rhs.versionFingerprint
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
        hasher.combine(versionFingerprint)
    }
}

enum ApplicationLocation {
    static let systemApplications = URL(fileURLWithPath: "/System/Applications", isDirectory: true)
    static let systemUtilities = systemApplications
        .appendingPathComponent("Utilities", isDirectory: true)
    static let localApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
    static let networkApplications = URL(fileURLWithPath: "/Network/Applications", isDirectory: true)

    static var userApplications: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    }

    static var scanRoots: [URL] {
        [systemApplications, systemUtilities, localApplications, userApplications, networkApplications]
    }

    static func containsUserVisibleApplication(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return scanRoots.contains { root in
            let rootPath = root.standardizedFileURL.path
            return path == rootPath || path.hasPrefix(rootPath + "/")
        }
    }
}
