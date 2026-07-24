import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let applicationCatalog = ApplicationCatalog()
    private let iconRepository = IconRepository()
    private let applicationLauncher = ApplicationLauncher()
    private let hotKeyManager = HotKeyManager()
    private lazy var launchpadWindowController = LaunchpadWindowController(
        iconRepository: iconRepository,
        applicationLauncher: applicationLauncher
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        hotKeyManager.handler = { [weak self] in
            self?.launchpadWindowController.toggle()
        }
        launchpadWindowController.shortcutRegistrar = { [weak self] configuration in
            guard let self else { return .failure(.registrationUnavailable) }
            return hotKeyManager.register(configuration)
        }
        _ = hotKeyManager.register(.defaultConfiguration)
        launchpadWindowController.startHotCornerMonitoring()
        applicationCatalog.delegate = launchpadWindowController
        applicationCatalog.start()
        configureMainMenu()
        observeTerminationConditions()
        DispatchQueue.main.async { [weak self] in
            self?.launchpadWindowController.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        launchpadWindowController.toggle()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        applicationCatalog.stop()
        launchpadWindowController.stopHotCornerMonitoring()
        iconRepository.removeAllMemoryObjects()
        launchpadWindowController.hideImmediately()
    }

    @objc private func toggleLaunchpad() {
        launchpadWindowController.toggle()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    @objc private func showSettings() {
        launchpadWindowController.showSettings()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let toggleItem = NSMenuItem(
            title: "显示或隐藏启动台",
            action: #selector(toggleLaunchpad),
            keyEquivalent: "l"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        appMenu.addItem(toggleItem)

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 Classic Launchpad",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func observeTerminationConditions() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.launchpadWindowController.screenParametersDidChange()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.launchpadWindowController.hideImmediately()
        }
    }
}
