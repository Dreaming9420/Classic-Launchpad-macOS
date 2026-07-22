import Foundation
import OSLog

protocol ApplicationCatalogDelegate: AnyObject {
    func applicationCatalog(_ catalog: ApplicationCatalog, didUpdate applications: [InstalledApplication])
}

final class ApplicationCatalog: NSObject {
    weak var delegate: ApplicationCatalogDelegate?

    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "ApplicationCatalog"
    )

    private let scanner = ApplicationScanner()
    private let metadataQuery = NSMetadataQuery()
    private var applicationsByIdentity: [String: InstalledApplication] = [:]
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        metadataQuery.predicate = NSPredicate(
            format: "%K == %@",
            kMDItemContentTypeTree as String,
            "com.apple.application-bundle"
        )
        metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]
        metadataQuery.notificationBatchingInterval = CatalogTiming.updateBatchInterval
    }

    deinit {
        stop()
    }

    func start() {
        guard !metadataQuery.isStarted else { return }
        observeQuery()
        metadataQuery.start()

        Task { [weak self] in
            guard let self else { return }
            let discovered = await scanner.scanStandardLocations()
            await MainActor.run {
                self.mergeAndPublish(discovered)
            }
        }
    }

    func stop() {
        if metadataQuery.isStarted {
            metadataQuery.stop()
        }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func observeQuery() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSMetadataQueryDidFinishGathering,
            .NSMetadataQueryDidUpdate
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: metadataQuery, queue: .main) { [weak self] _ in
                self?.refreshFromMetadataQuery()
            }
        }
    }

    private func refreshFromMetadataQuery() {
        metadataQuery.disableUpdates()
        let urls = metadataQuery.results.compactMap { result -> URL? in
            guard
                let item = result as? NSMetadataItem,
                let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        metadataQuery.enableUpdates()

        Task { [weak self] in
            guard let self else { return }
            let discovered = await scanner.scanStandardLocations(additionalURLs: urls)
            await MainActor.run {
                self.replaceAndPublish(discovered)
            }
        }
    }

    private func mergeAndPublish(_ applications: [InstalledApplication]) {
        for application in applications {
            applicationsByIdentity[application.identity.stableKey] = application
        }
        publish()
    }

    private func replaceAndPublish(_ applications: [InstalledApplication]) {
        applicationsByIdentity = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.identity.stableKey, $0) }
        )
        publish()
    }

    private func publish() {
        let applications = Array(applicationsByIdentity.values)
        Self.logger.info("Application catalog contains \(applications.count, privacy: .public) launchable items")
        delegate?.applicationCatalog(self, didUpdate: applications)
    }
}

private enum CatalogTiming {
    static let updateBatchInterval: TimeInterval = 0.8
}
