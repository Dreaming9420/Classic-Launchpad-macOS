import AppKit
import OSLog

final class LaunchpadWindowController: NSWindowController, LaunchpadRootViewDelegate, NSWindowDelegate {
    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "LaunchpadWindow"
    )

    private let iconRepository: IconRepository
    private let applicationLauncher: ApplicationLauncher
    private let layoutStore = LayoutStore()
    private let layoutMerger = LayoutMerger()
    private let hotCornerStore: HotCornerStore
    private let systemHotCornerReader = SystemHotCornerReader()
    private lazy var hotCornerManager: HotCornerManager = {
        let manager = HotCornerManager()
        manager.handler = { [weak self] in
            self?.show()
        }
        return manager
    }()
    private var rootView: LaunchpadRootView?
    private var savedPresentationOptions: NSApplication.PresentationOptions?
    private(set) var isPresented = false
    private var isTransitioning = false
    private var applications: [InstalledApplication] = []
    private var snapshot: LayoutSnapshot?
    private var savedDocument: LayoutDocument?
    private var hasLoadedSavedDocument = false
    private var activeDisplayID: CGDirectDisplayID?
    private var settingsWindowController: SettingsWindowController?
    private var showSystemApplications = UserDefaults.standard.object(
        forKey: PreferenceKey.showSystemApplications
    ) as? Bool ?? true
    private var hotCornerConfiguration: HotCornerConfiguration
    var shortcutRegistrar: ((HotKeyConfiguration) -> Result<Void, HotKeyRegistrationError>)?

    init(iconRepository: IconRepository, applicationLauncher: ApplicationLauncher) {
        let hotCornerStore = HotCornerStore()
        self.iconRepository = iconRepository
        self.applicationLauncher = applicationLauncher
        self.hotCornerStore = hotCornerStore
        hotCornerConfiguration = hotCornerStore.load()
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func toggle() {
        isPresented ? hide() : show()
    }

    func startHotCornerMonitoring() {
        refreshHotCornerMonitoring()
        hotCornerManager.start()
    }

    func stopHotCornerMonitoring() {
        hotCornerManager.stop()
    }

    func showSettings() {
        hideImmediately()
        let configuration = snapshot?.document.shortcut ?? .defaultConfiguration
        let hotCornerConflicts = refreshHotCornerMonitoring()
        let controller: SettingsWindowController
        if let settingsWindowController {
            controller = settingsWindowController
            controller.update(
                configuration: configuration,
                showSystemApplications: showSystemApplications,
                sortMode: snapshot?.document.sortMode ?? .defaultOrder,
                hotCornerConfiguration: hotCornerConfiguration
            )
        } else {
            controller = SettingsWindowController(
                configuration: configuration,
                showSystemApplications: showSystemApplications,
                sortMode: snapshot?.document.sortMode ?? .defaultOrder,
                hotCornerConfiguration: hotCornerConfiguration
            )
            controller.delegate = self
            settingsWindowController = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.presentSystemHotCornerConflict(hotCornerConflicts)
    }

    func show() {
        guard !isPresented, !isTransitioning, let screen = targetScreen() else { return }
        isTransitioning = true

        let panel = LaunchpadPanel(screen: screen)
        panel.delegate = self
        let rootView = LaunchpadRootView(frame: screen.frame, iconRepository: iconRepository)
        rootView.delegate = self
        rootView.prepareBackground(for: screen)
        panel.contentView = rootView
        panel.setFrame(screen.frame, display: true)

        window = panel
        self.rootView = rootView
        activeDisplayID = displayID(for: screen)
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions.formUnion([.autoHideDock, .autoHideMenuBar])
        panel.orderFrontRegardless()
        panel.makeKey()
        rootView.focusInitialResponder()
        if let snapshot {
            rootView.apply(snapshot, animated: false)
        }
        rootView.animateEntrance()

        isPresented = true
        isTransitioning = false
    }

    func hide() {
        guard isPresented, !isTransitioning, let rootView else { return }
        isTransitioning = true
        rootView.animateExit { [weak self] in
            self?.finishHiding()
        }
    }

    func hideImmediately() {
        guard isPresented || isTransitioning else { return }
        finishHiding()
    }

    private func finishHiding() {
        rootView?.releaseHeavyResources()
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        rootView = nil
        activeDisplayID = nil
        restorePresentationOptions()
        isPresented = false
        isTransitioning = false
    }

    private func restorePresentationOptions() {
        if let savedPresentationOptions {
            NSApp.presentationOptions = savedPresentationOptions
        }
        savedPresentationOptions = nil
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSApp.keyWindow?.screen
            ?? NSScreen.main
    }

    func screenParametersDidChange() {
        guard isPresented, let activeDisplayID else { return }
        guard let screen = NSScreen.screens.first(where: { displayID(for: $0) == activeDisplayID }) else {
            hideImmediately()
            return
        }
        window?.setFrame(screen.frame, display: true)
        rootView?.frame = CGRect(origin: .zero, size: screen.frame.size)
        rootView?.prepareBackground(for: screen)
        rootView?.needsLayout = true
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    @discardableResult
    private func refreshHotCornerMonitoring() -> Set<HotCornerPosition> {
        let conflicts = systemHotCornerReader.conflicts(for: hotCornerConfiguration)
        hotCornerManager.update(
            configuration: hotCornerConfiguration,
            systemConflicts: conflicts
        )
        return conflicts
    }

    func launchpadRootViewRequestedClose(_ rootView: LaunchpadRootView) {
        hide()
    }

    func launchpadRootView(
        _ rootView: LaunchpadRootView,
        requestedLaunch application: InstalledApplication
    ) {
        applicationLauncher.launch(application) { [weak self] result in
            switch result {
            case .success:
                self?.hide()
            case .failure(let error):
                self?.presentLaunchError(error)
            }
        }
    }

    func launchpadRootView(_ rootView: LaunchpadRootView, didMutate document: LayoutDocument) {
        applyUserDocument(document)
    }

    func launchpadRootView(
        _ rootView: LaunchpadRootView,
        requestedRemoval application: InstalledApplication
    ) {
        guard application.canMoveToTrash, let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "将“\(application.displayName)”移到废纸篓？"
        alert.informativeText = "应用及其中内容将被移到废纸篓。"
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.applicationLauncher.moveToTrash(application) { result in
                switch result {
                case .success:
                    self?.removeApplicationFromLayout(application.identity)
                case .failure(let error):
                    self?.presentRemovalError(error)
                }
            }
        }
    }

    private func presentLaunchError(_ error: Error) {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法打开应用"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: window)
    }

    private func presentRemovalError(_ error: Error) {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法移到废纸篓"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: window)
    }

    private func applyUserDocument(_ document: LayoutDocument) {
        guard var snapshot else { return }
        snapshot.document = document
        self.snapshot = snapshot
        savedDocument = document
        rootView?.apply(snapshot, animated: true)
        Task {
            do {
                try await layoutStore.save(document)
            } catch {
                Self.logger.error("Unable to save the customized layout: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func removeApplicationFromLayout(_ identity: ApplicationIdentity) {
        guard let snapshot else { return }
        var items: [LayoutItem] = []
        for item in snapshot.document.items {
            switch item {
            case .application(let candidate) where candidate.stableKey == identity.stableKey:
                continue
            case .folder(var folder):
                folder.applications.removeAll { $0.stableKey == identity.stableKey }
                if folder.applications.count >= 2 {
                    items.append(.folder(folder))
                } else if let remaining = folder.applications.first {
                    items.append(.application(remaining))
                }
            default:
                items.append(item)
            }
        }
        applyUserDocument(LayoutDocument(
            items: items,
            sortMode: .custom,
            shortcut: snapshot.document.shortcut
        ))
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isPresented, !isTransitioning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + WindowTiming.deactivationGraceInterval) { [weak self] in
            guard let self, isPresented, !isTransitioning, !NSApp.isActive else { return }
            hide()
        }
    }

    func windowWillClose(_ notification: Notification) {
        restorePresentationOptions()
    }
}

private enum WindowTiming {
    static let deactivationGraceInterval: TimeInterval = 0.12
}

extension LaunchpadWindowController: ApplicationCatalogDelegate {
    func applicationCatalog(_ catalog: ApplicationCatalog, didUpdate applications: [InstalledApplication]) {
        self.applications = applications
        refreshLayout()
    }

    private func refreshLayout() {
        if !hasLoadedSavedDocument {
            hasLoadedSavedDocument = true
            Task { [weak self] in
                guard let self else { return }
                let loaded = await layoutStore.load()
                await MainActor.run {
                    self.savedDocument = loaded
                    self.mergeCurrentApplications()
                }
            }
        } else {
            mergeCurrentApplications()
        }
    }

    private func mergeCurrentApplications() {
        let snapshot = layoutMerger.merge(
            saved: savedDocument,
            applications: displayedApplications
        )
        self.snapshot = snapshot
        savedDocument = snapshot.document
        rootView?.apply(snapshot, animated: true)
        if case .failure(let error) = shortcutRegistrar?(snapshot.document.shortcut) {
            Self.logger.error("Unable to register the saved shortcut: \(error.localizedDescription, privacy: .public)")
        }

        Task {
            do {
                try await layoutStore.save(snapshot.document)
            } catch {
                Self.logger.error("Unable to save the application layout: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private var displayedApplications: [InstalledApplication] {
        showSystemApplications ? applications : applications.filter { !$0.isSystemApplication }
    }

}

extension LaunchpadWindowController: SettingsWindowControllerDelegate {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        requestedShortcut configuration: HotKeyConfiguration
    ) -> Result<Void, HotKeyRegistrationError> {
        guard let shortcutRegistrar else { return .failure(.registrationUnavailable) }
        let result = shortcutRegistrar(configuration)
        guard case .success = result, var document = snapshot?.document else { return result }
        document.shortcut = configuration
        applyUserDocument(document)
        return .success(())
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didChangeShowSystemApplications isEnabled: Bool
    ) {
        guard showSystemApplications != isEnabled else { return }
        showSystemApplications = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.showSystemApplications)
        if hasLoadedSavedDocument {
            mergeCurrentApplications()
        }
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        didChangeSortMode sortMode: ApplicationSortMode
    ) {
        guard let document = snapshot?.document, document.sortMode != sortMode else { return }
        let shortcut = document.shortcut
        switch sortMode {
        case .defaultOrder:
            applyUserDocument(layoutMerger.makeDefault(displayedApplications, shortcut: shortcut))
        case .name:
            applyUserDocument(layoutMerger.makeNameSorted(displayedApplications, shortcut: shortcut))
        case .recentlyAdded:
            applyUserDocument(layoutMerger.makeRecentlyAdded(displayedApplications, shortcut: shortcut))
        case .custom:
            var customizedDocument = document
            customizedDocument.sortMode = .custom
            applyUserDocument(customizedDocument)
        }
    }

    func settingsWindowController(
        _ controller: SettingsWindowController,
        requestedHotCorner position: HotCornerPosition?,
        assignment: HotCornerAssignment
    ) -> HotCornerUpdateResult {
        guard
            let position
        else {
            hotCornerConfiguration.select(nil, assignment: .disabled)
            hotCornerStore.save(hotCornerConfiguration)
            refreshHotCornerMonitoring()
            return .applied
        }
        guard !systemHotCornerReader.isConfigured(position) else {
            return .systemConflict
        }
        hotCornerConfiguration.select(position, assignment: assignment)
        hotCornerStore.save(hotCornerConfiguration)
        refreshHotCornerMonitoring()
        return .applied
    }

    func settingsWindowControllerRequestedDefaultLayout(_ controller: SettingsWindowController) {
        let shortcut = snapshot?.document.shortcut ?? .defaultConfiguration
        applyUserDocument(layoutMerger.makeDefault(displayedApplications, shortcut: shortcut))
    }
}

private enum PreferenceKey {
    static let showSystemApplications = "showSystemApplications"
}
