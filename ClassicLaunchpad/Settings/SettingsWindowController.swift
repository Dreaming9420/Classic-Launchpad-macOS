import AppKit

protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowController(
        _ controller: SettingsWindowController,
        requestedShortcut configuration: HotKeyConfiguration
    ) -> Result<Void, HotKeyRegistrationError>
    func settingsWindowControllerRequestedDefaultLayout(_ controller: SettingsWindowController)
}

final class SettingsWindowController: NSWindowController, ShortcutRecorderViewDelegate {
    weak var delegate: SettingsWindowControllerDelegate?
    private let recorderView: ShortcutRecorderView
    private let statusLabel = NSTextField(labelWithString: "")
    private var acceptedConfiguration: HotKeyConfiguration

    init(configuration: HotKeyConfiguration) {
        acceptedConfiguration = configuration
        recorderView = ShortcutRecorderView(frame: .zero, configuration: configuration)
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
        configureContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }
        let title = NSTextField(labelWithString: "全局快捷键")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.frame = CGRect(x: 28, y: 178, width: 120, height: 22)
        contentView.addSubview(title)

        recorderView.frame = CGRect(x: 190, y: 166, width: 220, height: 42)
        recorderView.delegate = self
        contentView.addSubview(recorderView)

        let hint = NSTextField(labelWithString: "点击快捷键框，然后按下新的组合键。无需辅助功能权限。")
        hint.textColor = .secondaryLabelColor
        hint.font = NSFont.systemFont(ofSize: 12)
        hint.frame = CGRect(x: 28, y: 132, width: 390, height: 20)
        contentView.addSubview(hint)

        statusLabel.textColor = .systemRed
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.frame = CGRect(x: 28, y: 104, width: 390, height: 20)
        contentView.addSubview(statusLabel)

        let separator = NSBox(frame: CGRect(x: 28, y: 84, width: 384, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)

        let resetButton = NSButton(
            title: "恢复默认布局",
            target: self,
            action: #selector(confirmResetLayout)
        )
        resetButton.bezelStyle = .rounded
        resetButton.frame = CGRect(x: 28, y: 30, width: 138, height: 32)
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

    func update(configuration: HotKeyConfiguration) {
        acceptedConfiguration = configuration
        recorderView.setConfiguration(configuration)
        statusLabel.stringValue = ""
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
            delegate?.settingsWindowControllerRequestedDefaultLayout(self)
        }
    }
}

private enum SettingsSize {
    static let window = CGSize(width: 440, height: 230)
}
