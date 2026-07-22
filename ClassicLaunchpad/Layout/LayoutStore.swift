import Foundation
import OSLog

actor LayoutStore {
    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "LayoutStore"
    )

    private let fileManager: FileManager
    private let layoutURL: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init() {
        let manager = FileManager.default
        fileManager = manager
        let applicationSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        let directory = applicationSupport.appendingPathComponent("QitaiClassicLaunchpad", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        layoutURL = directory.appendingPathComponent("Layout.json", isDirectory: false)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> LayoutDocument? {
        guard fileManager.fileExists(atPath: layoutURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: layoutURL)
            let document = try decoder.decode(LayoutDocument.self, from: data)
            guard (1...LayoutDocument.currentVersion).contains(document.version) else { return nil }
            return document
        } catch {
            Self.logger.error("Saved layout is unreadable and will be regenerated: \(error.localizedDescription, privacy: .public)")
            preserveCorruptFile()
            return nil
        }
    }

    func save(_ document: LayoutDocument) throws {
        let data = try encoder.encode(document)
        try data.write(to: layoutURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func preserveCorruptFile() {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = layoutURL
            .deletingLastPathComponent()
            .appendingPathComponent("Layout.corrupt-\(timestamp).json", isDirectory: false)
        do {
            try fileManager.moveItem(at: layoutURL, to: destination)
        } catch {
            Self.logger.error("Unable to preserve a corrupt layout file: \(error.localizedDescription, privacy: .public)")
        }
    }
}
