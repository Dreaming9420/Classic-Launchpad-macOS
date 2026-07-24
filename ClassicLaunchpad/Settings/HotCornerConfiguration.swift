import AppKit
import OSLog

enum HotCornerPosition: String, Codable, CaseIterable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var title: String {
        switch self {
        case .topLeft:
            return "左上"
        case .topRight:
            return "右上"
        case .bottomLeft:
            return "左下"
        case .bottomRight:
            return "右下"
        }
    }

    var systemPreferenceKey: String {
        switch self {
        case .topLeft:
            return "wvous-tl-corner"
        case .topRight:
            return "wvous-tr-corner"
        case .bottomLeft:
            return "wvous-bl-corner"
        case .bottomRight:
            return "wvous-br-corner"
        }
    }
}

struct HotCornerAssignment: Codable, Equatable {
    var isEnabled: Bool
    var modifierRawValue: UInt

    static let disabled = HotCornerAssignment(isEnabled: false, modifierRawValue: 0)

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierRawValue)
            .intersection(HotCornerModifier.supported)
    }

    func displayTitle(for position: HotCornerPosition) -> String {
        var title = ""
        if modifierFlags.contains(.control) { title += "⌃" }
        if modifierFlags.contains(.option) { title += "⌥" }
        if modifierFlags.contains(.shift) { title += "⇧" }
        if modifierFlags.contains(.command) { title += "⌘" }
        return title.isEmpty ? position.title : "\(title) \(position.title)"
    }
}

struct HotCornerConfiguration: Codable, Equatable {
    var topLeft = HotCornerAssignment.disabled
    var topRight = HotCornerAssignment.disabled
    var bottomLeft = HotCornerAssignment.disabled
    var bottomRight = HotCornerAssignment.disabled

    subscript(position: HotCornerPosition) -> HotCornerAssignment {
        get {
            switch position {
            case .topLeft:
                return topLeft
            case .topRight:
                return topRight
            case .bottomLeft:
                return bottomLeft
            case .bottomRight:
                return bottomRight
            }
        }
        set {
            switch position {
            case .topLeft:
                topLeft = newValue
            case .topRight:
                topRight = newValue
            case .bottomLeft:
                bottomLeft = newValue
            case .bottomRight:
                bottomRight = newValue
            }
        }
    }

    var enabledPositions: Set<HotCornerPosition> {
        Set(HotCornerPosition.allCases.filter { self[$0].isEnabled })
    }

    var selectedPosition: HotCornerPosition? {
        HotCornerPosition.allCases.first { self[$0].isEnabled }
    }

    mutating func select(
        _ position: HotCornerPosition?,
        assignment: HotCornerAssignment
    ) {
        for candidate in HotCornerPosition.allCases {
            self[candidate] = .disabled
        }
        if let position {
            self[position] = assignment
        }
    }

    mutating func normalizeSelection() {
        guard let selectedPosition else { return }
        let assignment = self[selectedPosition]
        select(selectedPosition, assignment: assignment)
    }
}

enum HotCornerModifier {
    static let supported: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
}

final class HotCornerStore {
    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "HotCornerStore"
    )

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HotCornerConfiguration {
        guard let data = defaults.data(forKey: PreferenceKey.configuration) else {
            return HotCornerConfiguration()
        }
        do {
            var configuration = try JSONDecoder().decode(HotCornerConfiguration.self, from: data)
            configuration.normalizeSelection()
            return configuration
        } catch {
            Self.logger.error(
                "Unable to load hot corner configuration: \(error.localizedDescription, privacy: .public)"
            )
            return HotCornerConfiguration()
        }
    }

    func save(_ configuration: HotCornerConfiguration) {
        do {
            defaults.set(
                try JSONEncoder().encode(configuration),
                forKey: PreferenceKey.configuration
            )
        } catch {
            Self.logger.error(
                "Unable to save hot corner configuration: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

final class SystemHotCornerReader {
    private let applicationID = "com.apple.dock" as CFString

    func isConfigured(_ position: HotCornerPosition) -> Bool {
        CFPreferencesAppSynchronize(applicationID)
        guard let value = CFPreferencesCopyAppValue(
            position.systemPreferenceKey as CFString,
            applicationID
        ) as? NSNumber else {
            return false
        }
        return value.intValue > SystemHotCornerValue.disabled
    }

    func conflicts(for configuration: HotCornerConfiguration) -> Set<HotCornerPosition> {
        Set(configuration.enabledPositions.filter(isConfigured))
    }
}

private enum PreferenceKey {
    static let configuration = "hotCornerConfiguration"
}

private enum SystemHotCornerValue {
    static let disabled = 1
}
