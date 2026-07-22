import AppKit

protocol LaunchpadSearchFieldEventDelegate: AnyObject {
    func launchpadSearchFieldDidPressEscape(_ searchField: LaunchpadSearchField)
    func launchpadSearchFieldDidPressReturn(_ searchField: LaunchpadSearchField)
    func launchpadSearchField(_ searchField: LaunchpadSearchField, didNavigate direction: GridNavigationDirection)
    func launchpadSearchField(_ searchField: LaunchpadSearchField, didRequestPageDelta delta: Int)
    func launchpadSearchField(_ searchField: LaunchpadSearchField, didReceiveScroll event: NSEvent)
}

final class LaunchpadSearchField: NSSearchField {
    weak var eventDelegate: LaunchpadSearchFieldEventDelegate?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let searchCell = CenteredSearchFieldCell(textCell: "")
        cell = searchCell
        isEditable = true
        isSelectable = true
        alignment = .center
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        textColor = .white
        font = NSFont.systemFont(ofSize: 14, weight: .regular)
        placeholderString = ""
        searchCell.placeholderString = ""
        searchCell.searchButtonCell = nil
        searchCell.cancelButtonCell = nil
        searchCell.prompt = NSAttributedString(
            string: "搜索",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.76),
                .font: NSFont.systemFont(ofSize: 14, weight: .regular)
            ]
        )
        setAccessibilityPlaceholderValue("搜索")
        wantsLayer = true
        layer?.backgroundColor = LaunchpadColors.searchFill.cgColor
        layer?.cornerRadius = LaunchpadMetrics.searchHeight / 2
        layer?.borderColor = NSColor.white.withAlphaComponent(0.17).cgColor
        layer?.borderWidth = 0.5
    }

    required init?(coder: NSCoder) {
        nil
    }

    func beginEditing(with event: NSEvent) {
        selectText(nil)
        alignCurrentEditor()
        currentEditor()?.keyDown(with: event)
    }

    func alignCurrentEditor() {
        if let editor = currentEditor() as? NSTextView {
            editor.alignment = .center
            editor.textContainerInset = .zero
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            if event.keyCode == SearchKey.left {
                eventDelegate?.launchpadSearchField(self, didRequestPageDelta: -1)
                return
            }
            if event.keyCode == SearchKey.right {
                eventDelegate?.launchpadSearchField(self, didRequestPageDelta: 1)
                return
            }
        }

        switch event.keyCode {
        case SearchKey.escape:
            eventDelegate?.launchpadSearchFieldDidPressEscape(self)
        case SearchKey.returnKey, SearchKey.keypadEnter:
            eventDelegate?.launchpadSearchFieldDidPressReturn(self)
        case SearchKey.left:
            eventDelegate?.launchpadSearchField(self, didNavigate: .left)
        case SearchKey.right:
            eventDelegate?.launchpadSearchField(self, didNavigate: .right)
        case SearchKey.up:
            eventDelegate?.launchpadSearchField(self, didNavigate: .up)
        case SearchKey.down:
            eventDelegate?.launchpadSearchField(self, didNavigate: .down)
        default:
            super.keyDown(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        eventDelegate?.launchpadSearchField(self, didReceiveScroll: event)
    }
}

private final class CenteredSearchFieldCell: NSSearchFieldCell {
    var prompt: NSAttributedString?
    private let promptImage: NSImage?

    override init(textCell string: String) {
        let color = NSColor.white.withAlphaComponent(0.72)
        let pointConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let colorConfiguration = NSImage.SymbolConfiguration(paletteColors: [color])
        promptImage = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "搜索")?
            .withSymbolConfiguration(pointConfiguration.applying(colorConfiguration))
        promptImage?.isTemplate = false
        super.init(textCell: string)
    }

    required init(coder: NSCoder) {
        promptImage = nil
        super.init(coder: coder)
    }

    override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObject: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        super.edit(
            withFrame: centeredEditingRect(in: rect),
            in: controlView,
            editor: textObject,
            delegate: delegate,
            event: event
        )
    }

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObject: NSText,
        delegate: Any?,
        start selectionStart: Int,
        length selectionLength: Int
    ) {
        super.select(
            withFrame: centeredEditingRect(in: rect),
            in: controlView,
            editor: textObject,
            delegate: delegate,
            start: selectionStart,
            length: selectionLength
        )
    }

    private func centeredEditingRect(in rect: NSRect) -> NSRect {
        let fallbackFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let lineHeight = ceil((font ?? fallbackFont).boundingRectForFont.height)
        return CGRect(
            x: rect.minX,
            y: floor(rect.midY - lineHeight / 2),
            width: rect.width,
            height: lineHeight
        )
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let isEditing = (controlView as? NSSearchField)?.currentEditor() != nil
        guard stringValue.isEmpty, !isEditing, let prompt, let promptImage else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        let textSize = prompt.size()
        let contentWidth = SearchPromptLayout.imageSize.width
            + SearchPromptLayout.spacing
            + textSize.width
        let contentX = cellFrame.midX - contentWidth / 2
        let imageRect = CGRect(
            x: contentX,
            y: cellFrame.midY - SearchPromptLayout.imageSize.height / 2,
            width: SearchPromptLayout.imageSize.width,
            height: SearchPromptLayout.imageSize.height
        )
        promptImage.draw(
            in: imageRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        prompt.draw(at: CGPoint(
            x: imageRect.maxX + SearchPromptLayout.spacing,
            y: cellFrame.midY - textSize.height / 2
        ))
    }
}

private enum SearchPromptLayout {
    static let imageSize = CGSize(width: 14, height: 14)
    static let spacing: CGFloat = 5
}

private enum SearchKey {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
}
