import Foundation

enum ApplicationSortMode: String, Codable, CaseIterable {
    case defaultOrder
    case name
    case recentlyAdded
    case custom

    var title: String {
        switch self {
        case .defaultOrder:
            return "默认顺序"
        case .name:
            return "按名称"
        case .recentlyAdded:
            return "最近添加"
        case .custom:
            return "自定义"
        }
    }
}

struct FolderLayout: Codable, Hashable {
    let id: UUID
    var name: String
    var applications: [ApplicationIdentity]
}

enum LayoutItem: Codable, Hashable {
    case application(ApplicationIdentity)
    case folder(FolderLayout)

    private enum CodingKeys: String, CodingKey {
        case kind
        case application
        case folder
    }

    private enum Kind: String, Codable {
        case application
        case folder
    }

    var stableID: String {
        switch self {
        case .application(let identity):
            return "application:\(identity.stableKey)"
        case .folder(let folder):
            return "folder:\(folder.id.uuidString)"
        }
    }

    var applicationIdentities: [ApplicationIdentity] {
        switch self {
        case .application(let identity):
            return [identity]
        case .folder(let folder):
            return folder.applications
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .application:
            self = .application(try container.decode(ApplicationIdentity.self, forKey: .application))
        case .folder:
            self = .folder(try container.decode(FolderLayout.self, forKey: .folder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .application(let identity):
            try container.encode(Kind.application, forKey: .kind)
            try container.encode(identity, forKey: .application)
        case .folder(let folder):
            try container.encode(Kind.folder, forKey: .kind)
            try container.encode(folder, forKey: .folder)
        }
    }
}

struct LayoutDocument: Codable, Hashable {
    static let currentVersion = 4

    var version: Int
    var items: [LayoutItem]
    var sortMode: ApplicationSortMode
    var shortcut: HotKeyConfiguration

    init(
        items: [LayoutItem],
        sortMode: ApplicationSortMode = .defaultOrder,
        shortcut: HotKeyConfiguration = .defaultConfiguration
    ) {
        version = Self.currentVersion
        self.items = items
        self.sortMode = sortMode
        self.shortcut = shortcut
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case items
        case isCustomized
        case sortMode
        case shortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        items = try container.decode([LayoutItem].self, forKey: .items)
        let wasCustomized = try container.decodeIfPresent(Bool.self, forKey: .isCustomized) ?? false
        sortMode = try container.decodeIfPresent(ApplicationSortMode.self, forKey: .sortMode)
            ?? (wasCustomized ? .custom : .defaultOrder)
        shortcut = try container.decodeIfPresent(HotKeyConfiguration.self, forKey: .shortcut)
            ?? .defaultConfiguration
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .version)
        try container.encode(items, forKey: .items)
        try container.encode(sortMode == .custom, forKey: .isCustomized)
        try container.encode(sortMode, forKey: .sortMode)
        try container.encode(shortcut, forKey: .shortcut)
    }
}

struct LayoutSnapshot {
    var document: LayoutDocument
    var applicationsByKey: [String: InstalledApplication]

    func application(for identity: ApplicationIdentity) -> InstalledApplication? {
        applicationsByKey[identity.stableKey]
    }
}
