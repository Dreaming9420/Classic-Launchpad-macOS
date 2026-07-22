import Foundation

final class ApplicationNameResolver {
    private enum InfoKey {
        static let displayName = "CFBundleDisplayName"
        static let bundleName = "CFBundleName"
    }

    private let simplifiedChinesePreferences = ["zh_CN", "zh-Hans", "zh-CN", "zh"]

    func displayName(for bundle: Bundle, url: URL, metadataDisplayName: String?) -> String {
        if let name = localizedName(
            for: bundle,
            preferences: simplifiedChinesePreferences,
            keys: [InfoKey.displayName, InfoKey.bundleName]
        ) {
            return name
        }

        if let name = localizedTableName(for: bundle, keys: [InfoKey.displayName, InfoKey.bundleName]) {
            return name
        }

        if let localized = bundle.localizedInfoDictionary {
            if let displayName = nonEmptyString(localized[InfoKey.displayName]) {
                return displayName
            }
            if let bundleName = nonEmptyString(localized[InfoKey.bundleName]) {
                return bundleName
            }
        }

        if let metadataDisplayName = nonEmptyString(metadataDisplayName) {
            return (metadataDisplayName as NSString).deletingPathExtension
        }

        if let info = bundle.infoDictionary {
            if let displayName = nonEmptyString(info[InfoKey.displayName]) {
                return displayName
            }
            if let bundleName = nonEmptyString(info[InfoKey.bundleName]) {
                return bundleName
            }
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private func localizedTableName(for bundle: Bundle, keys: [String]) -> String? {
        guard
            let tableURL = bundle.url(forResource: "InfoPlist", withExtension: "loctable"),
            let data = try? Data(contentsOf: tableURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let localizations = plist as? [String: Any]
        else {
            return nil
        }

        for localization in simplifiedChinesePreferences {
            guard let values = localizations[localization] as? [String: Any] else { continue }
            for key in keys {
                if let value = nonEmptyString(values[key]) {
                    return value
                }
            }
        }
        return nil
    }

    private func localizedName(
        for bundle: Bundle,
        preferences: [String],
        keys: [String]
    ) -> String? {
        let preferred = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: preferences
        )

        for localization in preferred {
            guard
                let stringsURL = bundle.url(
                    forResource: "InfoPlist",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: localization
                ),
                let data = try? Data(contentsOf: stringsURL),
                let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                let values = plist as? [String: Any]
            else {
                continue
            }

            for key in keys {
                if let value = nonEmptyString(values[key]) {
                    return value
                }
            }
        }

        return nil
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
