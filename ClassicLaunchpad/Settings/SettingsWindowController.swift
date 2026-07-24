import AppKit

enum HotCornerUpdateResult {
    case applied
    case systemConflict
}

protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        requestedShortcut configuration: HotKeyConfiguration
    ) -> Result<Void, HotKeyRegistrationError>
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didChangeShowSystemApplications isEnabled: Bool
    )
    func settingsWindowController(
        _ controller: SettingsWindowController,
        didChangeSortMode sortMode: ApplicationSortMode
    )
    func settingsWindowController(
        _ controller: SettingsWindowController,
        requestedHotCorner position: HotCornerPosition?,
        assignment: HotCornerAssignment
    ) -> HotCornerUpdateResult
    func settingsWindowControllerRequestedDefaultLayout(_ controller: SettingsWindowController)
}

final class SettingsWindowController: NSWindowController, ShortcutRecorderViewDelegate {
    weak var delegate: SettingsWindowControllerDelegate?
    private let recorderView: ShortcutRecorderView
    private let showSystemApplicationsButton: NSButton
    private let sortModeButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hotCornerButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(labelWithString: "")
    private var acceptedConfiguration: HotKeyConfiguration
    private var acceptedSortMode: ApplicationSortMode
    private var hotCornerConfiguration: HotCornerConfiguration

    init(
        configuration: HotKeyConfiguration,
        showSystemApplications: Bool,
        sortMode: ApplicationSortMode,
        hotCornerConfiguration: HotCornerConfiguration
    ) {
        acceptedConfiguration = configuration
        acceptedSortMode = sortMode
        self.hotCornerConfiguration = hotCornerConfiguration
        recorderView = ShortcutRecorderView(frame: .zero, configuration: configuration)
        showSystemApplicationsButton = NSButton(
            checkboxWithTitle: "显示系统应用",
            target: nil,
            action: nil
        )
        showSystemApplicationsButton.state = showSystemApplications ? .on : .off
        for mode in ApplicationSortMode.allCases {
            sortModeButton.addItem(withTitle: mode.title)
            sortModeButton.lastItem?.representedObject = mode.rawValue
        }
        hotCornerButton.addItem(withTitle: "关闭")
        hotCornerButton.lastItem?.representedObject = HotCornerMenuValue.disabled
        for position in HotCornerPosition.allCases {
            hotCornerButton.addItem(withTitle: position.title)
            hotCornerButton.lastItem?.representedObject = position.rawValue
        }
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: SettingsSize.window),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Classic Launchpad 设置"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        selectSortMode(sortMode)
        refreshHotCornerButton()
        configureContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }
        let title = NSTextField(labelWithString: "全局快捷键")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.frame = CGRect(x: 28, y: 354, width: 120, height: 22)
        contentView.addSubview(title)

        recorderView.frame = CGRect(x: 190, y: 342, width: 220, height: 42)
        recorderView.delegate = self
        contentView.addSubview(recorderView)

        let hint = NSTextField(labelWithString: "点击快捷键框，然后按下新的组合键。无需辅助功能权限。")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.frame = CGRect(x: 28, y: 308, width: 390, height: 20)
        contentView.addSubview(hint)

        statusLabel.textColor = .systemRed
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.frame = CGRect(x: 28, y: 280, width: 390, height: 20)
        contentView.addSubview(statusLabel)

        let separator = NSBox(frame: CGRect(x: 28, y: 260, width: 384, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        showSystemApplicationsButton.target = self
        showSystemApplicationsButton.action = #selector(showSystemApplicationsChanged)
        showSystemApplicationsButton.frame = CGRect(x: 28, y: 220, width: 180, height: 24)
        contentView.addSubview(showSystemApplicationsButton)

        let sortModeLabel = NSTextField(labelWithString: "排序方式")
        sortModeLabel.frame = CGRect(x: 28, y: 178, width: 120, height: 22)
        contentView.addSubview(sortModeLabel)

        sortModeButton.target = self
        sortModeButton.action = #selector(sortModeChanged)
        sortModeButton.frame = CGRect(x: 190, y: 172, width: 220, height: 32)
        contentView.addSubview(sortModeButton)

        let hotCornerLabel = NSTextField(labelWithString: "触发角")
        hotCornerLabel.frame = CGRect(x: 28, y: 136, width: 120, height: 22)
        contentView.addSubview(hotCornerLabel)

        hotCornerButton.target = self
        hotCornerButton.action = #selector(hotCornerChanged)
        hotCornerButton.frame = CGRect(x: 190, y: 130, width: 220, height: 32)
        contentView.addSubview(hotCornerButton)

        let hotCornerHint = NSTextField(labelWithString: "按住修饰键选择，可设置组合键触发。")
        hotCornerHint.textColor = .secondaryLabelColor
        hotCornerHint.font = NSFont.systemFont(ofSize: 12)
        hotCornerHint.frame = CGRect(x: 28, y: 96, width: 384, height: 20)
        contentView.addSubview(hotCornerHint)

        let footerSeparator = NSBox(frame: CGRect(x: 28, y: 78, width: 384, height: 1))
        footerSeparator.boxType = .separator
        contentView.addSubview(footerSeparator)

        let resetButton = NSButton(
            title: "恢复默认布局",
            target: self,
            action: #selector(confirmResetLayout)
        )
        resetButton.bezelStyle = .rounded
        resetButton.frame = CGRect(x: 28, y: 26, width: 138, height: 32)
        contentView.addSubview(resetButton)
    }

    func shortcutRecorderView(
        _ recorderView: ShortcutRecorderView,
        didRecord configuration: HotKeyConfiguration
    ) {
        switch delegate?.settingsWindowController(self, requestedShortcut: configuration) {
        case .success:
            acceptedConfiguration = configuration
            statusLabel.stringValue = ""
        case .failure(let error):
            recorderView.setConfiguration(acceptedConfiguration)
            statusLabel.stringValue = error.localizedDescription
        case nil:
            break
        }
    }

    func update(
        configuration: HotKeyConfiguration,
        showSystemApplications: Bool,
        sortMode: ApplicationSortMode,
        hotCornerConfiguration: HotCornerConfiguration
    ) {
        acceptedConfiguration = configuration
        acceptedSortMode = sortMode
        self.hotCornerConfiguration = hotCornerConfiguration
        recorderView.setConfiguration(configuration)
        showSystemApplicationsButton.state = showSystemApplications ? .on : .off
        selectSortMode(sortMode)
        refreshHotCornerButton()
        statusLabel.stringValue = ""
    }

    @objc private func showSystemApplicationsChanged() {
        delegate?.settingsWindowController(
            self,
            didChangeShowSystemApplications: showSystemApplicationsButton.state == .on
        )
    }

    @objc private func sortModeChanged() {
        guard
            let rawValue = sortModeButton.selectedItem?.representedObject as? String,
            let sortMode = ApplicationSortMode(rawValue: rawValue),
            sortMode != acceptedSortMode
        else {
            return
        }
        guard acceptedSortMode == .custom, sortMode != .custom else {
            applySortMode(sortMode)
            return
        }
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "重新排列应用？"
        alert.informativeText = "切换排序方式会清除当前手动排列和自定义文件夹。"
        alert.addButton(withTitle: "重新排列")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn {
                applySortMode(sortMode)
            } else {
                selectSortMode(acceptedSortMode)
            }
        }
    }

    private func applySortMode(_ sortMode: ApplicationSortMode) {
        acceptedSortMode = sortMode
        selectSortMode(sortMode)
        delegate?.settingsWindowController(self, didChangeSortMode: sortMode)
    }

    private func selectSortMode(_ sortMode: ApplicationSortMode) {
        sortModeButton.selectItem(withTitle: sortMode.title)
    }

    @objc private func hotCornerChanged() {
        guard let rawValue = hotCornerButton.selectedItem?.representedObject as? String else {
            return
        }
        let position = HotCornerPosition(rawValue: rawValue)
        let modifierFlags = NSApp.currentEvent?.modifierFlags
            .intersection(HotCornerModifier.supported) ?? []
        let assignment = position == nil
            ? .disabled
            : HotCornerAssignment(isEnabled: true, modifierRawValue: modifierFlags.rawValue)

        switch delegate?.settingsWindowController(
            self,
            requestedHotCorner: position,
            assignment: assignment
        ) {
        case .applied:
            hotCornerConfiguration.select(position, assignment: assignment)
            refreshHotCornerButton()
        case .systemConflict:
            refreshHotCornerButton()
            if let position {
                presentSystemHotCornerConflict([position])
            }
        case nil:
            refreshHotCornerButton()
        }
    }

    func presentSystemHotCornerConflict(_ positions: Set<HotCornerPosition>) {
        guard !positions.isEmpty, let window, window.attachedSheet == nil else { return }
        let names = HotCornerPosition.allCases
            .filter(positions.contains)
            .map(\.title)
            .joined(separator: "、")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "系统触发角已占用"
        alert.informativeText = "\(names)已被 macOS 系统触发角占用，请先在“桌面与程序坞”中将对应位置设为“—”。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { response in
            guard
                response == .alertFirstButtonReturn,
                let url = URL(string: SystemSettingsLink.desktopAndDock)
            else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshHotCornerButton() {
        for position in HotCornerPosition.allCases {
            guard let item = hotCornerButton.itemArray.first(where: {
                ($0.representedObject as? String) == position.rawValue
            }) else {
                continue
            }
            item.title = position.title
        }
        guard let position = hotCornerConfiguration.selectedPosition else {
            hotCornerButton.selectItem(at: HotCornerMenuIndex.disabled)
            return
        }
        let assignment = hotCornerConfiguration[position]
        guard let item = hotCornerButton.itemArray.first(where: {
            ($0.representedObject as? String) == position.rawValue
        }) else {
            return
        }
        item.title = assignment.displayTitle(for: position)
        hotCornerButton.select(item)
    }

    @objc private func confirmResetLayout() {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "恢复默认布局？"
        alert.informativeText = "应用顺序、页面和文件夹将恢复为自动生成的布局。"
        alert.addButton(withTitle: "恢复")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            acceptedSortMode = .defaultOrder
            selectSortMode(.defaultOrder)
            delegate?.settingsWindowControllerRequestedDefaultLayout(self)
        }
    }
}

private enum SettingsSize {
    static let window = CGSize(width: 440, height: 406)
}

private enum HotCornerMenuIndex {
    static let disabled = 0
}

private enum HotCornerMenuValue {
    static let disabled = ""
}

private enum SystemSettingsLink {
    static let desktopAndDock = "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
}
