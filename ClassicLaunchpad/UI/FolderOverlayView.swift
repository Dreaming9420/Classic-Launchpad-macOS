import AppKit

protocol FolderOverlayViewDelegate: AnyObject {
    func folderOverlayViewRequestedClose(_ overlayView: FolderOverlayView)
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        requestedLaunch application: InstalledApplication
    )
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        renamedFolder folderID: UUID,
        to name: String
    )
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        reordered applications: [ApplicationIdentity],
        in folderID: UUID
    )
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        beganDragging identity: ApplicationIdentity,
        from folderID: UUID,
        at pointInWindow: CGPoint
    )
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        continuedDraggingAt pointInWindow: CGPoint
    )
    func folderOverlayView(
        _ overlayView: FolderOverlayView,
        endedDraggingAt pointInWindow: CGPoint
    )
}

final class FolderOverlayView: NSView, NSTextFieldDelegate {
    weak var delegate: FolderOverlayViewDelegate?

    private var folder: FolderLayout
    private let snapshot: LayoutSnapshot
    private let iconRepository: IconRepository
    private let panelView = FlippedVisualEffectView()
    private let titleField = NSTextField()
    private var tiles: [String: IconTileLayer] = [:]
    private var itemFrames: [CGRect] = []
    private var pressedIdentity: ApplicationIdentity?
    private var dragStartPoint: CGPoint?
    private var dragPointerOffset = CGPoint.zero
    private var originalApplications: [ApplicationIdentity]?
    private var reorderWorkItem: DispatchWorkItem?
    private var pendingTargetIndex: Int?
    private var isDraggingItem = false
    private var isDraggingOutside = false

    override var isFlipped: Bool { true }

    init(
        frame frameRect: NSRect,
        folder: FolderLayout,
        snapshot: LayoutSnapshot,
        iconRepository: IconRepository
    ) {
        self.folder = folder
        self.snapshot = snapshot
        self.iconRepository = iconRepository
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configure() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.16).cgColor

        panelView.material = .popover
        panelView.blendingMode = .withinWindow
        panelView.state = .active
        panelView.wantsLayer = true
        panelView.layer?.cornerRadius = FolderPanel.cornerRadius
        panelView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        panelView.layer?.borderWidth = 0.5
        addSubview(panelView)

        titleField.stringValue = folder.name
        titleField.alignment = .center
        titleField.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleField.textColor = .white
        titleField.isBezeled = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.delegate = self
        panelView.addSubview(titleField)
    }

    override func layout() {
        super.layout()
        let applicationCount = folder.applications.count
        let columns = min(max(applicationCount, 1), FolderPanel.maximumColumns)
        let rows = max(Int(ceil(Double(applicationCount) / Double(columns))), 1)
        let panelWidth = max(
            CGFloat(columns) * FolderPanel.itemPitch + FolderPanel.horizontalPadding * 2,
            FolderPanel.minimumWidth
        )
        let panelHeight = CGFloat(rows) * FolderPanel.rowPitch
            + FolderPanel.titleAreaHeight
            + FolderPanel.bottomPadding
        panelView.frame = CGRect(
            x: bounds.midX - panelWidth / 2,
            y: bounds.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
        titleField.frame = CGRect(
            x: FolderPanel.horizontalPadding,
            y: FolderPanel.titleTop,
            width: panelWidth - FolderPanel.horizontalPadding * 2,
            height: FolderPanel.titleHeight
        )

        rebuildTiles(columns: columns, animated: false)
    }

    func animateOpen() {
        alphaValue = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = MotionSpec.folderDuration
        fade.timingFunction = MotionSpec.entranceTiming
        layer?.add(fade, forKey: "folder.open")

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.84
        scale.toValue = 1
        scale.duration = MotionSpec.folderDuration
        scale.timingFunction = MotionSpec.entranceTiming
        panelView.layer?.add(scale, forKey: "folder.scale")
    }

    func animateClose(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = MotionSpec.folderDuration
            animator().alphaValue = 0
        } completionHandler: {
            completion()
        }
    }

    func focusTitle() {
        window?.makeFirstResponder(titleField)
        titleField.currentEditor()?.selectAll(nil)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        delegate?.folderOverlayView(self, renamedFolder: folder.id, to: titleField.stringValue)
    }

    private func rebuildTiles(columns: Int, animated: Bool) {
        let liveKeys = Set(folder.applications.map(\.stableKey))
        let obsoleteKeys = tiles.keys.filter { !liveKeys.contains($0) }
        for key in obsoleteKeys {
            tiles.removeValue(forKey: key)?.removeFromSuperlayer()
        }
        itemFrames.removeAll(keepingCapacity: true)
        let gridWidth = CGFloat(columns) * FolderPanel.itemPitch
        let originX = (panelView.bounds.width - gridWidth) / 2
        let displayScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? FolderDrag.layoutDuration : 0)
        CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        for (index, identity) in folder.applications.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = CGRect(
                x: originX + CGFloat(column) * FolderPanel.itemPitch
                    + (FolderPanel.itemPitch - LaunchpadMetrics.itemWidth) / 2,
                y: FolderPanel.titleAreaHeight + CGFloat(row) * FolderPanel.rowPitch,
                width: LaunchpadMetrics.itemWidth,
                height: LaunchpadMetrics.itemHeight
            )
            itemFrames.append(frame)
            let tile = tiles[identity.stableKey] ?? IconTileLayer()
            if tile.superlayer == nil {
                panelView.layer?.addSublayer(tile)
                tiles[identity.stableKey] = tile
            }
            if !isDragging(identity) {
                tile.frame = frame
            }
            if let application = snapshot.application(for: identity) {
                tile.configure(
                    with: application,
                    iconRepository: iconRepository,
                    displayScale: displayScale
                )
            }
            tile.setNeedsLayout()
        }
        CATransaction.commit()
    }

    private func isDragging(_ identity: ApplicationIdentity) -> Bool {
        isDraggingItem && pressedIdentity?.stableKey == identity.stableKey
    }

    private func itemIndex(at point: CGPoint) -> Int? {
        let localPoint = convert(point, to: panelView)
        return itemFrames.firstIndex(where: { $0.contains(localPoint) })
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard panelView.frame.contains(point) else {
            delegate?.folderOverlayViewRequestedClose(self)
            return
        }
        guard let pressedIndex = itemIndex(at: point), pressedIndex < folder.applications.count else {
            return
        }
        pressedIdentity = folder.applications[pressedIndex]
        dragStartPoint = point
        originalApplications = nil
        isDraggingItem = false
        isDraggingOutside = false
        tiles[folder.applications[pressedIndex].stableKey]?.setPressed(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressedIdentity, let dragStartPoint else { return }
        if isDraggingOutside {
            delegate?.folderOverlayView(self, continuedDraggingAt: event.locationInWindow)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if !isDraggingItem {
            guard hypot(point.x - dragStartPoint.x, point.y - dragStartPoint.y) >= FolderPanel.dragThreshold else {
                return
            }
            beginDragging(identity: pressedIdentity, at: point)
        }
        moveDraggedTile(to: point)
        if !panelView.frame.insetBy(dx: -FolderPanel.exitMargin, dy: -FolderPanel.exitMargin).contains(point) {
            cancelReorder()
            isDraggingOutside = true
            tiles[pressedIdentity.stableKey]?.opacity = 0
            delegate?.folderOverlayView(
                self,
                beganDragging: pressedIdentity,
                from: folder.id,
                at: event.locationInWindow
            )
            return
        }
        guard let targetIndex = itemIndex(at: point),
              let currentIndex = folder.applications.firstIndex(where: {
                  $0.stableKey == pressedIdentity.stableKey
              }),
              targetIndex != currentIndex else {
            cancelReorder()
            return
        }
        scheduleReorder(identity: pressedIdentity, to: targetIndex)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingOutside {
            delegate?.folderOverlayView(self, endedDraggingAt: event.locationInWindow)
            resetDragState()
            return
        }
        guard let pressedIdentity else { return }
        tiles[pressedIdentity.stableKey]?.setPressed(false)
        if isDraggingItem {
            finishInternalDrag(identity: pressedIdentity)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        defer { resetDragState() }
        guard let releasedIndex = itemIndex(at: point),
              releasedIndex < folder.applications.count,
              folder.applications[releasedIndex].stableKey == pressedIdentity.stableKey,
              let application = snapshot.application(for: pressedIdentity) else {
            return
        }
        delegate?.folderOverlayView(self, requestedLaunch: application)
    }

    private func beginDragging(identity: ApplicationIdentity, at point: CGPoint) {
        guard let index = folder.applications.firstIndex(where: { $0.stableKey == identity.stableKey }),
              index < itemFrames.count,
              let tile = tiles[identity.stableKey] else {
            return
        }
        originalApplications = folder.applications
        isDraggingItem = true
        let localPoint = convert(point, to: panelView)
        let frame = itemFrames[index]
        dragPointerOffset = CGPoint(x: localPoint.x - frame.midX, y: localPoint.y - frame.midY)
        tile.setPressed(false)
        tile.zPosition = FolderDrag.zPosition
        tile.opacity = FolderDrag.opacity
        let lift = CABasicAnimation(keyPath: "transform.scale")
        lift.fromValue = 1
        lift.toValue = FolderDrag.scale
        lift.duration = MotionSpec.dragLiftDuration
        lift.timingFunction = MotionSpec.entranceTiming
        tile.transform = CATransform3DMakeScale(FolderDrag.scale, FolderDrag.scale, 1)
        tile.add(lift, forKey: "folder.drag.lift")
    }

    private func moveDraggedTile(to point: CGPoint) {
        guard let pressedIdentity, let tile = tiles[pressedIdentity.stableKey] else { return }
        let localPoint = convert(point, to: panelView)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tile.position = CGPoint(
            x: localPoint.x - dragPointerOffset.x,
            y: localPoint.y - dragPointerOffset.y
        )
        CATransaction.commit()
    }

    private func scheduleReorder(identity: ApplicationIdentity, to targetIndex: Int) {
        guard pendingTargetIndex != targetIndex else { return }
        cancelReorder()
        pendingTargetIndex = targetIndex
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  pendingTargetIndex == targetIndex,
                  let sourceIndex = folder.applications.firstIndex(where: {
                      $0.stableKey == identity.stableKey
                  }) else {
                return
            }
            pendingTargetIndex = nil
            reorderWorkItem = nil
            let movedIdentity = folder.applications.remove(at: sourceIndex)
            folder.applications.insert(movedIdentity, at: min(targetIndex, folder.applications.count))
            let columns = min(max(folder.applications.count, 1), FolderPanel.maximumColumns)
            rebuildTiles(columns: columns, animated: true)
        }
        reorderWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + FolderDrag.reorderDwell, execute: workItem)
    }

    private func cancelReorder() {
        reorderWorkItem?.cancel()
        reorderWorkItem = nil
        pendingTargetIndex = nil
    }

    private func finishInternalDrag(identity: ApplicationIdentity) {
        cancelReorder()
        guard let tile = tiles[identity.stableKey],
              let index = folder.applications.firstIndex(where: { $0.stableKey == identity.stableKey }),
              index < itemFrames.count else {
            resetDragState()
            return
        }
        let applicationsChanged = originalApplications != folder.applications
        let targetFrame = itemFrames[index]
        CATransaction.begin()
        CATransaction.setAnimationDuration(FolderDrag.dropDuration)
        CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        CATransaction.setCompletionBlock { [weak self, weak tile] in
            guard let self else { return }
            tile?.removeAllAnimations()
            tile?.zPosition = 0
            tile?.opacity = 1
            tile?.transform = CATransform3DIdentity
            if applicationsChanged {
                delegate?.folderOverlayView(self, reordered: folder.applications, in: folder.id)
            }
            resetDragState()
        }
        tile.opacity = 1
        tile.transform = CATransform3DIdentity
        tile.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        CATransaction.commit()
    }

    private func resetDragState() {
        cancelReorder()
        if let pressedIdentity, let tile = tiles[pressedIdentity.stableKey] {
            tile.setPressed(false)
            tile.removeAllAnimations()
            tile.zPosition = 0
            tile.opacity = 1
            tile.transform = CATransform3DIdentity
        }
        pressedIdentity = nil
        dragStartPoint = nil
        dragPointerOffset = .zero
        originalApplications = nil
        isDraggingItem = false
        isDraggingOutside = false
    }
}

private final class FlippedVisualEffectView: NSVisualEffectView {
    override var isFlipped: Bool { true }
}

private enum FolderPanel {
    static let maximumColumns = 7
    static let itemPitch: CGFloat = 146
    static let rowPitch: CGFloat = 142
    static let horizontalPadding: CGFloat = 34
    static let minimumWidth: CGFloat = 560
    static let titleAreaHeight: CGFloat = 78
    static let titleTop: CGFloat = 18
    static let titleHeight: CGFloat = 30
    static let bottomPadding: CGFloat = 28
    static let cornerRadius: CGFloat = 24
    static let dragThreshold: CGFloat = 8
    static let exitMargin: CGFloat = 24
}

private enum FolderDrag {
    static let scale: CGFloat = 1.1
    static let opacity: Float = 0.94
    static let zPosition: CGFloat = 100
    static let reorderDwell: TimeInterval = 0.1
    static let layoutDuration: CFTimeInterval = 0.24
    static let dropDuration: CFTimeInterval = 0.2
}
