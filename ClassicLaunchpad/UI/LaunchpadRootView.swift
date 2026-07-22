import AppKit
import QuartzCore

protocol LaunchpadRootViewDelegate: AnyObject {
    func launchpadRootViewRequestedClose(_ rootView: LaunchpadRootView)
    func launchpadRootView(
        _ rootView: LaunchpadRootView,
        requestedLaunch application: InstalledApplication
    )
    func launchpadRootView(_ rootView: LaunchpadRootView, didMutate document: LayoutDocument)
    func launchpadRootView(
        _ rootView: LaunchpadRootView,
        requestedRemoval application: InstalledApplication
    )
}

final class LaunchpadRootView: NSView {
    weak var delegate: LaunchpadRootViewDelegate?

    private let backgroundLayer = CALayer()
    private let fallbackEffectView = NSVisualEffectView()
    private let dimLayer = CAGradientLayer()
    private let backgroundRenderer = DesktopBackgroundRenderer()
    private let gridView: LaunchpadGridView
    private let searchField = LaunchpadSearchField(frame: .zero)
    private let searchController = SearchController()
    private let folderInteractionController = FolderInteractionController()
    private let iconRepository: IconRepository
    private var sourceSnapshot: LayoutSnapshot?
    private var folderOverlayView: FolderOverlayView?
    private var optionEditWorkItem: DispatchWorkItem?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    init(frame frameRect: NSRect, iconRepository: IconRepository) {
        self.iconRepository = iconRepository
        gridView = LaunchpadGridView(frame: frameRect, iconRepository: iconRepository)
        super.init(frame: frameRect)
        configureLayers()
        gridView.delegate = self
        addSubview(gridView)
        searchField.delegate = self
        searchField.eventDelegate = self
        searchField.layer?.zPosition = 2
        addSubview(searchField, positioned: .above, relativeTo: gridView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true

        backgroundLayer.contentsGravity = .resizeAspectFill
        backgroundLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundLayer.zPosition = -3
        layer?.addSublayer(backgroundLayer)

        fallbackEffectView.blendingMode = .behindWindow
        fallbackEffectView.material = .fullScreenUI
        fallbackEffectView.state = .active
        fallbackEffectView.isHidden = true
        addSubview(fallbackEffectView, positioned: .above, relativeTo: nil)
        fallbackEffectView.layer?.zPosition = -2

        dimLayer.colors = [
            NSColor.black.withAlphaComponent(0.22).cgColor,
            LaunchpadColors.dim.cgColor,
            NSColor.black.withAlphaComponent(0.36).cgColor
        ]
        dimLayer.locations = [0, 0.52, 1]
        dimLayer.zPosition = -1
        layer?.addSublayer(dimLayer)
        gridView.layer?.zPosition = 1
    }

    func prepareBackground(for screen: NSScreen) {
        fallbackEffectView.isHidden = true
        backgroundRenderer.render(for: screen) { [weak self] image in
            guard let self else { return }
            if let image {
                backgroundLayer.contents = image
                fallbackEffectView.isHidden = true
            } else {
                backgroundLayer.contents = nil
                fallbackEffectView.isHidden = false
            }
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer.bounds = bounds
        backgroundLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        dimLayer.frame = bounds
        fallbackEffectView.frame = bounds
        gridView.frame = bounds
        folderOverlayView?.frame = bounds
        searchField.frame = CGRect(
            x: bounds.midX - LaunchpadMetrics.searchWidth / 2,
            y: LaunchpadMetrics.searchTopOffset,
            width: LaunchpadMetrics.searchWidth,
            height: LaunchpadMetrics.searchHeight
        )
        CATransaction.commit()
    }

    func apply(_ snapshot: LayoutSnapshot, animated: Bool) {
        sourceSnapshot = snapshot
        updateSearchResults(animated: animated, resetPage: false)
    }

    func focusInitialResponder() {
        window?.makeFirstResponder(self)
        cancelOptionEditActivation()
        gridView.setOptionKeyPressed(false)
        searchField.needsDisplay = true
    }

    func animateEntrance() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = reduceMotion ? MotionSpec.reducedMotionDuration : MotionSpec.entranceDuration

        backgroundLayer.opacity = 1
        gridView.layer?.opacity = 1
        searchField.layer?.opacity = 1
        dimLayer.opacity = 1

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = duration
        fade.timingFunction = MotionSpec.entranceTiming
        gridView.layer?.add(fade, forKey: "entrance.opacity")
        searchField.layer?.add(fade, forKey: "entrance.opacity")
        dimLayer.add(fade, forKey: "entrance.dim")

        guard !reduceMotion else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = LaunchpadMetrics.backgroundScale
        scale.toValue = 1
        scale.duration = duration
        scale.timingFunction = MotionSpec.entranceTiming
        backgroundLayer.add(scale, forKey: "entrance.scale")
    }

    func animateExit(completion: @escaping () -> Void) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = reduceMotion ? MotionSpec.reducedMotionDuration : MotionSpec.exitDuration
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        fade.timingFunction = MotionSpec.exitTiming
        fade.isRemovedOnCompletion = false
        fade.fillMode = .forwards
        gridView.layer?.add(fade, forKey: "exit.opacity")
        searchField.layer?.add(fade, forKey: "exit.opacity")
        dimLayer.add(fade, forKey: "exit.dim")

        if !reduceMotion {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1
            scale.toValue = LaunchpadMetrics.backgroundScale
            scale.duration = duration
            scale.timingFunction = MotionSpec.exitTiming
            scale.isRemovedOnCompletion = false
            scale.fillMode = .forwards
            backgroundLayer.add(scale, forKey: "exit.scale")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: completion)
    }

    func releaseHeavyResources() {
        backgroundLayer.contents = nil
        backgroundLayer.removeAllAnimations()
        gridView.layer?.removeAllAnimations()
        searchField.layer?.removeAllAnimations()
        dimLayer.removeAllAnimations()
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.launchpadRootViewRequestedClose(self)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), event.keyCode == KeyCode.left {
            gridView.movePage(by: -1)
        } else if modifiers.contains(.command), event.keyCode == KeyCode.right {
            gridView.movePage(by: 1)
        } else if event.keyCode == KeyCode.escape {
            if folderOverlayView != nil {
                closeFolder()
            } else {
                delegate?.launchpadRootViewRequestedClose(self)
            }
        } else if event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter {
            gridView.activateSelection()
        } else if event.keyCode == KeyCode.left {
            gridView.navigate(.left)
        } else if event.keyCode == KeyCode.right {
            gridView.navigate(.right)
        } else if event.keyCode == KeyCode.up {
            gridView.navigate(.up)
        } else if event.keyCode == KeyCode.down {
            gridView.navigate(.down)
        } else if shouldBeginSearch(with: event, modifiers: modifiers) {
            searchField.beginEditing(with: event)
        } else {
            super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .option {
            scheduleOptionEditActivation()
        } else {
            cancelOptionEditActivation()
            gridView.setOptionKeyPressed(false)
        }
        super.flagsChanged(with: event)
    }

    private func scheduleOptionEditActivation() {
        guard optionEditWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            optionEditWorkItem = nil
            gridView.setOptionKeyPressed(true)
        }
        optionEditWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + OptionEditTiming.activationDelay,
            execute: workItem
        )
    }

    private func cancelOptionEditActivation() {
        optionEditWorkItem?.cancel()
        optionEditWorkItem = nil
    }

    private func shouldBeginSearch(
        with event: NSEvent,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        guard modifiers.intersection([.command, .control]).isEmpty else { return false }
        guard let characters = event.characters, !characters.isEmpty else { return false }
        return characters.unicodeScalars.contains {
            !CharacterSet.controlCharacters.contains($0)
        }
    }

    private func updateSearchResults(animated: Bool, resetPage: Bool = true) {
        guard let sourceSnapshot else { return }
        let filtered = searchController.filteredSnapshot(from: sourceSnapshot, query: searchField.stringValue)
        gridView.allowsLayoutMutation = searchField.stringValue.isEmpty
        if resetPage {
            gridView.resetToFirstPage(animated: animated)
        }
        gridView.apply(filtered, animated: animated)
    }

    private func openFolder(_ folder: FolderLayout) {
        guard folderOverlayView == nil, let sourceSnapshot else { return }
        let overlay = FolderOverlayView(
            frame: bounds,
            folder: folder,
            snapshot: sourceSnapshot,
            iconRepository: iconRepository
        )
        overlay.delegate = self
        overlay.layer?.zPosition = 4
        addSubview(overlay, positioned: .above, relativeTo: searchField)
        folderOverlayView = overlay
        overlay.animateOpen()
    }

    private func closeFolder() {
        guard let overlay = folderOverlayView else { return }
        folderOverlayView = nil
        overlay.animateClose {
            overlay.removeFromSuperview()
        }
        focusInitialResponder()
    }
}

extension LaunchpadRootView: LaunchpadGridViewDelegate {
    func launchpadGridView(
        _ gridView: LaunchpadGridView,
        didActivate application: InstalledApplication
    ) {
        delegate?.launchpadRootView(self, requestedLaunch: application)
    }

    func launchpadGridViewDidClickBackground(_ gridView: LaunchpadGridView) {
        delegate?.launchpadRootViewRequestedClose(self)
    }

    func launchpadGridView(_ gridView: LaunchpadGridView, didOpen folder: FolderLayout) {
        openFolder(folder)
    }

    func launchpadGridView(_ gridView: LaunchpadGridView, didMutate document: LayoutDocument) {
        guard var sourceSnapshot else { return }
        sourceSnapshot.document = document
        self.sourceSnapshot = sourceSnapshot
        delegate?.launchpadRootView(self, didMutate: document)
    }

    func launchpadGridView(
        _ gridView: LaunchpadGridView,
        requestedRemoval application: InstalledApplication
    ) {
        delegate?.launchpadRootView(self, requestedRemoval: application)
    }
}

private enum OptionEditTiming {
    static let activationDelay: TimeInterval = 0.12
}

extension LaunchpadRootView: NSSearchFieldDelegate, LaunchpadSearchFieldEventDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        searchField.alignCurrentEditor()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        searchField.needsDisplay = true
    }

    func controlTextDidChange(_ obj: Notification) {
        updateSearchResults(animated: false)
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            launchpadSearchFieldDidPressEscape(searchField)
        case #selector(NSResponder.insertNewline(_:)):
            launchpadSearchFieldDidPressReturn(searchField)
        case #selector(NSResponder.moveLeft(_:)):
            launchpadSearchField(searchField, didNavigate: .left)
        case #selector(NSResponder.moveRight(_:)):
            launchpadSearchField(searchField, didNavigate: .right)
        case #selector(NSResponder.moveUp(_:)):
            launchpadSearchField(searchField, didNavigate: .up)
        case #selector(NSResponder.moveDown(_:)):
            launchpadSearchField(searchField, didNavigate: .down)
        default:
            return false
        }
        return true
    }

    func launchpadSearchFieldDidPressEscape(_ searchField: LaunchpadSearchField) {
        if folderOverlayView != nil {
            closeFolder()
        } else if !searchField.stringValue.isEmpty {
            searchField.stringValue = ""
            updateSearchResults(animated: false)
        } else {
            delegate?.launchpadRootViewRequestedClose(self)
        }
    }

    func launchpadSearchFieldDidPressReturn(_ searchField: LaunchpadSearchField) {
        gridView.activateSelection()
    }

    func launchpadSearchField(
        _ searchField: LaunchpadSearchField,
        didNavigate direction: GridNavigationDirection
    ) {
        gridView.navigate(direction)
    }

    func launchpadSearchField(_ searchField: LaunchpadSearchField, didRequestPageDelta delta: Int) {
        gridView.movePage(by: delta)
    }

    func launchpadSearchField(_ searchField: LaunchpadSearchField, didReceiveScroll event: NSEvent) {
        gridView.handlePageScroll(event)
    }
}

extension LaunchpadRootView: FolderOverlayViewDelegate {
    func folderOverlayViewRequestedClose(_ overlayView: FolderOverlayView) {
        closeFolder()
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        requestedLaunch application: InstalledApplication
    ) {
        delegate?.launchpadRootView(self, requestedLaunch: application)
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        renamedFolder folderID: UUID,
        to name: String
    ) {
        guard var sourceSnapshot else { return }
        let document = folderInteractionController.rename(
            folderID: folderID,
            name: name,
            in: sourceSnapshot.document
        )
        sourceSnapshot.document = document
        self.sourceSnapshot = sourceSnapshot
        delegate?.launchpadRootView(self, didMutate: document)
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        reordered applications: [ApplicationIdentity],
        in folderID: UUID
    ) {
        guard var sourceSnapshot else { return }
        guard let document = folderInteractionController.reorder(
            applications: applications,
            in: folderID,
            document: sourceSnapshot.document
        ) else { return }
        sourceSnapshot.document = document
        self.sourceSnapshot = sourceSnapshot
        delegate?.launchpadRootView(self, didMutate: document)
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        beganDragging identity: ApplicationIdentity,
        from folderID: UUID,
        at pointInWindow: CGPoint
    ) {
        guard var sourceSnapshot else { return }
        let originalDocument = sourceSnapshot.document
        guard let document = folderInteractionController.extract(
            identity: identity,
            from: folderID,
            in: originalDocument
        ) else { return }
        sourceSnapshot.document = document
        self.sourceSnapshot = sourceSnapshot
        overlayView.alphaValue = 0
        gridView.apply(sourceSnapshot, animated: false)
        let point = gridView.convert(pointInWindow, from: nil)
        gridView.beginExternalDragging(
            stableID: LayoutItem.application(identity).stableID,
            at: point,
            originalDocument: originalDocument
        )
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        continuedDraggingAt pointInWindow: CGPoint
    ) {
        gridView.updateExternalDragging(at: gridView.convert(pointInWindow, from: nil))
    }

    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        endedDraggingAt pointInWindow: CGPoint
    ) {
        folderOverlayView = nil
        overlayView.removeFromSuperview()
        gridView.finishExternalDragging(at: gridView.convert(pointInWindow, from: nil))
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
}
