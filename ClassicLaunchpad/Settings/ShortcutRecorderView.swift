import AppKit

protocol ShortcutRecorderViewDelegate: AnyObject {
    func shortcutRecorderView(
        _ recorderView: ShortcutRecorderView,
        didRecord configuration: HotKeyConfiguration
    )
}

final class ShortcutRecorderView: NSView {
    weak var delegate: ShortcutRecorderViewDelegate?
    private let label = NSTextField(labelWithString: "")
    private(set) var configuration: HotKeyConfiguration

    override var acceptsFirstResponder: Bool { true }

    init(frame frameRect: NSRect, configuration: HotKeyConfiguration) {
        self.configuration = configuration
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        label.alignment = .center
        label.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
        addSubview(label)
        updateLabel()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 8, dy: 7)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        updateFocusAppearance()
    }

    override func keyDown(with event: NSEvent) {
        let configuration = HotKeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifierRawValue: event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .rawValue
        )
        guard configuration.isValid else {
            NSSound.beep()
            return
        }
        self.configuration = configuration
        updateLabel()
        delegate?.shortcutRecorderView(self, didRecord: configuration)
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        updateFocusAppearance()
        return result
    }

    func setConfiguration(_ configuration: HotKeyConfiguration) {
        self.configuration = configuration
        updateLabel()
    }

    private func updateLabel() {
        label.stringValue = configuration.displayString
    }

    private func updateFocusAppearance() {
        layer?.borderColor = window?.firstResponder === self
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
        layer?.borderWidth = window?.firstResponder === self ? 2 : 1
    }
}
