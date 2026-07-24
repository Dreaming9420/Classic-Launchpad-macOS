import AppKit
import QuartzCore

protocol LaunchpadGridViewDelegate: AnyObject {
    func launchpadGridView(_ gridView: LaunchpadGridView, didActivate application: InstalledApplication)
    func launchpadGridView(_ gridView: LaunchpadGridView, didOpen folder: FolderLayout)
    func launchpadGridView(_ gridView: LaunchpadGridView, didMutate document: LayoutDocument)
    func launchpadGridView(_ gridView: LaunchpadGridView, requestedRemoval application: InstalledApplication)
    func launchpadGridViewDidClickBackground(_ gridView: LaunchpadGridView)
}

final class LaunchpadGridView: NSView {
    weak var delegate: LaunchpadGridViewDelegate?
    var allowsLayoutMutation = true

    private let iconRepository: IconRepository
    private let pagesLayer = CALayer()
    private let dragOverlayLayer = CALayer()
    private let dragContentLayer = CALayer()
    private let pageIndicatorLayer = PageIndicatorLayer()
    private let selectionLayer = CALayer()
    private let keyboardNavigationController = KeyboardNavigationController()
    private let dragInteractionController = DragInteractionController()
    private let editModeController = EditModeController()
    private let folderInteractionController = FolderInteractionController()
    private var pageLayers: [CALayer] = []
    private var tileLayers: [String: CALayer] = [:]
    private var deleteBadgeLayers: [String: DeleteBadgeLayer] = [:]
    private var snapshot: LayoutSnapshot?
    private var geometry: GridGeometry?
    private var pressedItemIndex: Int?
    private var selectedItemIndex: Int?
    private var selectionVisible = false
    private var activeSwipeID: UUID?
    private var activeSwipeTargetPage: Int?
    private var lastDiscretePageTimestamp: TimeInterval = 0
    private var folderHoverWorkItem: DispatchWorkItem?
    private var reorderHoverWorkItem: DispatchWorkItem?
    private var edgePageWorkItem: DispatchWorkItem?
    private var pendingFolderTargetID: String?
    private var pendingEdgePageDelta: Int?
    private var folderReadyTargetID: String?
    private var pendingReorderTargetIndex: Int?
    private var dragOriginalDocument: LayoutDocument?
    private var dragProxyLayer: CALayer?
    private var lastDragPoint: CGPoint?
    private(set) var currentPage = 0

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        axis == .horizontal
    }

    init(frame frameRect: NSRect, iconRepository: IconRepository) {
        self.iconRepository = iconRepository
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.isGeometryFlipped = true
        pagesLayer.isGeometryFlipped = true
        layer?.addSublayer(pagesLayer)

        dragOverlayLayer.isGeometryFlipped = true
        dragOverlayLayer.zPosition = DragVisual.overlayZPosition
        dragContentLayer.isGeometryFlipped = true
        dragOverlayLayer.addSublayer(dragContentLayer)
        layer?.addSublayer(dragOverlayLayer)

        selectionLayer.borderColor = NSColor.white.withAlphaComponent(0.82).cgColor
        selectionLayer.borderWidth = 2
        selectionLayer.cornerRadius = 16
        selectionLayer.isHidden = true
        layer?.addSublayer(selectionLayer)
        layer?.addSublayer(pageIndicatorLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ snapshot: LayoutSnapshot, animated: Bool) {
        self.snapshot = snapshot
        if let selectedItemIndex, selectedItemIndex >= snapshot.document.items.count {
            self.selectedItemIndex = snapshot.document.items.isEmpty ? nil : 0
        }
        rebuild(animated: animated)
    }

    func resetToFirstPage(animated: Bool = true) {
        moveToPage(0, animated: animated)
    }

    func navigate(_ direction: GridNavigationDirection) {
        guard let geometry, let snapshot else { return }
        selectedItemIndex = keyboardNavigationController.destination(
            from: selectedItemIndex,
            direction: direction,
            columns: geometry.columns,
            itemCount: snapshot.document.items.count
        )
        selectionVisible = selectedItemIndex != nil
        if let selectedItemIndex {
            moveToPage(selectedItemIndex / geometry.pageCapacity, animated: true)
        }
        updateSelectionFrame(animated: true)
    }

    func activateSelection() {
        guard let snapshot, !snapshot.document.items.isEmpty else { return }
        let index = min(max(selectedItemIndex ?? 0, 0), snapshot.document.items.count - 1)
        switch snapshot.document.items[index] {
        case .application(let identity):
            if let application = snapshot.application(for: identity) {
                delegate?.launchpadGridView(self, didActivate: application)
            }
        case .folder(let folder):
            delegate?.launchpadGridView(self, didOpen: folder)
        }
    }

    func movePage(by delta: Int) {
        moveToPage(currentPage + delta, animated: true)
    }

    override func layout() {
        super.layout()
        rebuild(animated: false)
    }

    private func rebuild(animated: Bool) {
        guard let snapshot, bounds.width > 0, bounds.height > 0 else { return }
        let displayScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let safeInsets = window?.screen?.safeAreaInsets ?? NSEdgeInsets()
        let geometry = GridGeometry.make(
            in: bounds,
            safeAreaInsets: safeInsets,
            itemCount: snapshot.document.items.count
        )
        self.geometry = geometry
        currentPage = min(currentPage, geometry.pageCount - 1)
        while pageLayers.count < geometry.pageCount {
            let page = CALayer()
            page.isGeometryFlipped = true
            pagesLayer.addSublayer(page)
            pageLayers.append(page)
        }
        while pageLayers.count > geometry.pageCount {
            pageLayers.removeLast().removeFromSuperlayer()
        }

        let liveIDs = Set(snapshot.document.items.map(\.stableID))
        let obsoleteIDs = tileLayers.keys.filter { !liveIDs.contains($0) }
        for id in obsoleteIDs {
            tileLayers.removeValue(forKey: id)?.removeFromSuperlayer()
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? MotionSpec.layoutDuration : 0)
        CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        dragOverlayLayer.frame = bounds
        dragContentLayer.frame = dragOverlayLayer.bounds
        pagesLayer.frame = CGRect(
            x: -CGFloat(currentPage) * bounds.width,
            y: 0,
            width: CGFloat(geometry.pageCount) * bounds.width,
            height: bounds.height
        )
        for (index, pageLayer) in pageLayers.enumerated() {
            pageLayer.frame = CGRect(
                x: CGFloat(index) * bounds.width,
                y: 0,
                width: bounds.width,
                height: bounds.height
            )
        }

        for (index, item) in snapshot.document.items.enumerated() {
            let pageIndex = index / geometry.pageCapacity
            let positionOnPage = index % geometry.pageCapacity
            let tile = tileLayer(for: item, snapshot: snapshot, displayScale: displayScale)
            if tile.superlayer !== pageLayers[pageIndex] {
                tile.removeFromSuperlayer()
                pageLayers[pageIndex].addSublayer(tile)
            }
            tile.frame = geometry.itemFrames[positionOnPage]
            tile.setNeedsLayout()
        }
        CATransaction.commit()

        pageIndicatorLayer.frame = CGRect(
            x: 0,
            y: bounds.height - LaunchpadMetrics.pageIndicatorBottomOffset,
            width: bounds.width,
            height: 20
        )
        pageIndicatorLayer.configure(
            pageCount: geometry.pageCount,
            selectedPage: currentPage,
            displayScale: displayScale
        )
        pageIndicatorLayer.isHidden = geometry.pageCount <= 1
        updateSelectionFrame(animated: animated)
        updateEditAppearance(displayScale: displayScale)
    }

    private func tileLayer(
        for item: LayoutItem,
        snapshot: LayoutSnapshot,
        displayScale: CGFloat
    ) -> CALayer {
        if let existing = tileLayers[item.stableID] {
            configure(existing, for: item, snapshot: snapshot, displayScale: displayScale)
            return existing
        }
        let tile: CALayer = switch item {
        case .application: IconTileLayer()
        case .folder: FolderTileLayer()
        }
        tileLayers[item.stableID] = tile
        configure(tile, for: item, snapshot: snapshot, displayScale: displayScale)
        return tile
    }

    private func configure(
        _ tile: CALayer,
        for item: LayoutItem,
        snapshot: LayoutSnapshot,
        displayScale: CGFloat
    ) {
        switch (tile, item) {
        case let (iconTile as IconTileLayer, .application(identity)):
            if let application = snapshot.application(for: identity) {
                iconTile.configure(with: application, iconRepository: iconRepository, displayScale: displayScale)
            }
        case let (folderTile as FolderTileLayer, .folder(folder)):
            folderTile.configure(
                with: folder,
                applicationsByKey: snapshot.applicationsByKey,
                iconRepository: iconRepository,
                displayScale: displayScale
            )
        default:
            break
        }
    }

    private func itemIndex(at point: CGPoint) -> Int? {
        guard let geometry, let snapshot else { return nil }
        for position in 0..<geometry.pageCapacity {
            let index = currentPage * geometry.pageCapacity + position
            guard index < snapshot.document.items.count else { break }
            if geometry.itemFrames[position].contains(point) {
                return index
            }
        }
        return nil
    }

    private func setPressed(_ pressed: Bool, at index: Int) {
        guard let snapshot, index < snapshot.document.items.count else { return }
        let id = snapshot.document.items[index].stableID
        if let tile = tileLayers[id] as? IconTileLayer {
            tile.setPressed(pressed)
        } else if let tile = tileLayers[id] as? FolderTileLayer {
            tile.setPressed(pressed)
        }
    }

    private func enterEditMode() {
        guard allowsLayoutMutation else { return }
        editModeController.enter()
        updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
    }

    private func exitEditMode() {
        editModeController.exit()
        cancelDragScheduling()
        clearEditAppearance()
    }

    private func clearEditAppearance() {
        tileLayers.values.forEach { $0.removeAnimation(forKey: "edit.jiggle") }
        deleteBadgeLayers.values.forEach { $0.removeFromSuperlayer() }
        deleteBadgeLayers.removeAll()
    }

    func setOptionKeyPressed(_ pressed: Bool) {
        guard !pressed || allowsLayoutMutation else { return }
        let wasEditing = editModeController.isEditing
        editModeController.setOptionKeyPressed(pressed)
        guard wasEditing != editModeController.isEditing else { return }
        if editModeController.isEditing {
            updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
        } else {
            clearEditAppearance()
        }
    }

    private func updateEditAppearance(displayScale: CGFloat) {
        guard editModeController.isEditing, let snapshot, let geometry else { return }
        let draggedID: String?
        if case .dragging(let stableID, _, _) = dragInteractionController.state {
            draggedID = stableID
        } else {
            draggedID = nil
        }
        for (id, tile) in tileLayers where id != draggedID && tile.animation(forKey: "edit.jiggle") == nil {
            let jiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            jiggle.values = [-EditVisual.rotation, EditVisual.rotation, -EditVisual.rotation]
            jiggle.duration = EditVisual.duration
            jiggle.repeatCount = .infinity
            jiggle.beginTime = CACurrentMediaTime() + Double(abs(id.hashValue % 7)) * 0.012
            tile.add(jiggle, forKey: "edit.jiggle")
        }

        var visibleIDs = Set<String>()
        for (index, item) in snapshot.document.items.enumerated() {
            guard index / geometry.pageCapacity == currentPage,
                  item.stableID != draggedID,
                  case .application(let identity) = item,
                  let application = snapshot.application(for: identity),
                  application.canMoveToTrash else {
                continue
            }
            visibleIDs.insert(item.stableID)
            let badge = deleteBadgeLayers[item.stableID] ?? DeleteBadgeLayer()
            deleteBadgeLayers[item.stableID] = badge
            if badge.superlayer == nil { layer?.addSublayer(badge) }
            let itemFrame = geometry.itemFrames[index % geometry.pageCapacity]
            badge.frame = CGRect(
                x: itemFrame.minX + (itemFrame.width - LaunchpadMetrics.iconPointSize) / 2 - DeleteBadge.size / 2,
                y: itemFrame.minY - DeleteBadge.size / 3,
                width: DeleteBadge.size,
                height: DeleteBadge.size
            )
            badge.configure(displayScale: displayScale)
        }
        let hiddenIDs = deleteBadgeLayers.keys.filter { !visibleIDs.contains($0) }
        for id in hiddenIDs {
            deleteBadgeLayers.removeValue(forKey: id)?.removeFromSuperlayer()
        }
    }

    private func applicationForDeleteBadge(at point: CGPoint) -> InstalledApplication? {
        guard let snapshot else { return nil }
        for (id, badge) in deleteBadgeLayers where badge.frame.insetBy(dx: -4, dy: -4).contains(point) {
            guard let item = snapshot.document.items.first(where: { $0.stableID == id }),
                  case .application(let identity) = item else { continue }
            return snapshot.application(for: identity)
        }
        return nil
    }

    private func beginDragging(
        index: Int,
        point: CGPoint,
        originalDocument: LayoutDocument? = nil
    ) {
        guard let snapshot,
              index < snapshot.document.items.count,
              let rootLayer = layer else {
            return
        }
        enterEditMode()
        cancelDragScheduling()
        let item = snapshot.document.items[index]
        let stableID = item.stableID
        guard let tile = tileLayers[stableID],
              let proxy = makeDragProxy(from: tile) else {
            return
        }
        let visibleFrame = tile.convert(tile.bounds, to: dragContentLayer)
        let localPoint = dragContentLayer.convert(point, from: rootLayer)
        let pointerOffset = CGPoint(
            x: localPoint.x - visibleFrame.midX,
            y: localPoint.y - visibleFrame.midY
        )
        dragOriginalDocument = originalDocument ?? snapshot.document
        dragProxyLayer = proxy
        lastDragPoint = point
        dragInteractionController.beginDragging(
            stableID: stableID,
            index: index,
            pointerOffset: pointerOffset
        )

        tile.removeAnimation(forKey: "edit.jiggle")
        tile.removeAnimation(forKey: "press")
        proxy.removeAllAnimations()
        dragContentLayer.addSublayer(proxy)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dragOverlayLayer.frame = rootLayer.bounds
        dragContentLayer.frame = dragOverlayLayer.bounds
        tile.opacity = 0
        proxy.frame = visibleFrame
        proxy.setNeedsLayout()
        proxy.layoutIfNeeded()
        proxy.zPosition = DragVisual.zPosition
        proxy.opacity = DragVisual.opacity
        proxy.position = CGPoint(
            x: localPoint.x - pointerOffset.x,
            y: localPoint.y - pointerOffset.y
        )
        CATransaction.commit()

        let lift = CABasicAnimation(keyPath: "transform.scale")
        lift.fromValue = 1
        lift.toValue = DragVisual.scale
        lift.duration = MotionSpec.dragLiftDuration
        lift.timingFunction = MotionSpec.entranceTiming
        proxy.transform = CATransform3DMakeScale(DragVisual.scale, DragVisual.scale, 1)
        proxy.add(lift, forKey: "drag.lift")
        updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
    }

    private func makeDragProxy(from tile: CALayer) -> CALayer? {
        if let iconTile = tile as? IconTileLayer {
            return iconTile.makeDragRepresentation()
        }
        if let folderTile = tile as? FolderTileLayer {
            return folderTile.makeDragRepresentation()
        }
        return nil
    }

    func beginExternalDragging(
        stableID: String,
        at point: CGPoint,
        originalDocument: LayoutDocument
    ) {
        guard let index = snapshot?.document.items.firstIndex(where: { $0.stableID == stableID }) else {
            return
        }
        beginDragging(index: index, point: point, originalDocument: originalDocument)
    }

    func updateExternalDragging(at point: CGPoint) {
        updateDragging(at: point)
    }

    func finishExternalDragging(at point: CGPoint) {
        finishDragging(at: point)
    }

    private func updateDragging(at point: CGPoint) {
        guard case .dragging(let stableID, let currentIndex, let pointerOffset) = dragInteractionController.state,
              let snapshot,
              let geometry,
              let rootLayer = layer,
              let proxy = dragProxyLayer else {
            return
        }
        lastDragPoint = point
        let localPoint = dragContentLayer.convert(point, from: rootLayer)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        proxy.position = CGPoint(
            x: localPoint.x - pointerOffset.x,
            y: localPoint.y - pointerOffset.y
        )
        CATransaction.commit()

        scheduleEdgePagingIfNeeded(at: point)
        if let targetIndex = itemIndex(at: point), targetIndex != currentIndex {
            let target = snapshot.document.items[targetIndex]
            let targetFrame = geometry.itemFrames[targetIndex % geometry.pageCapacity]
            let iconFrame = CGRect(
                x: targetFrame.midX - LaunchpadMetrics.iconPointSize / 2,
                y: targetFrame.minY,
                width: LaunchpadMetrics.iconPointSize,
                height: LaunchpadMetrics.iconPointSize
            )
            let folderZone = iconFrame.insetBy(
                dx: DragVisual.folderActivationInset,
                dy: DragVisual.folderActivationInset
            )
            if folderZone.contains(point),
               case .application = snapshot.document.items[currentIndex] {
                cancelReorderPreview()
                scheduleFolderHover(targetID: target.stableID)
                return
            }
        }

        cancelFolderHover()
        guard let targetIndex = reorderTargetIndex(at: point), targetIndex != currentIndex else {
            cancelReorderPreview()
            return
        }
        scheduleReorderPreview(stableID: stableID, targetIndex: targetIndex)
    }

    private func reorderTargetIndex(at point: CGPoint) -> Int? {
        guard let geometry, let snapshot else { return nil }
        let targetArea = geometry.contentFrame.insetBy(
            dx: -LaunchpadMetrics.itemWidth / 2,
            dy: -LaunchpadMetrics.itemHeight / 2
        )
        guard targetArea.contains(point) else { return nil }
        let position = geometry.itemFrames.indices.min { left, right in
            let leftFrame = geometry.itemFrames[left]
            let rightFrame = geometry.itemFrames[right]
            return hypot(point.x - leftFrame.midX, point.y - leftFrame.midY)
                < hypot(point.x - rightFrame.midX, point.y - rightFrame.midY)
        }
        guard let position else { return nil }
        return min(currentPage * geometry.pageCapacity + position, snapshot.document.items.count)
    }

    private func scheduleReorderPreview(stableID: String, targetIndex: Int) {
        guard pendingReorderTargetIndex != targetIndex else { return }
        reorderHoverWorkItem?.cancel()
        pendingReorderTargetIndex = targetIndex
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, pendingReorderTargetIndex == targetIndex else { return }
            pendingReorderTargetIndex = nil
            reorderHoverWorkItem = nil
            reorderDraggedItem(stableID: stableID, to: targetIndex)
        }
        reorderHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + DragTiming.reorderDwell, execute: workItem)
    }

    private func cancelReorderPreview() {
        reorderHoverWorkItem?.cancel()
        reorderHoverWorkItem = nil
        pendingReorderTargetIndex = nil
    }

    private func reorderDraggedItem(stableID: String, to targetIndex: Int) {
        guard var snapshot,
              let sourceIndex = snapshot.document.items.firstIndex(where: { $0.stableID == stableID }),
              sourceIndex != targetIndex else {
            return
        }
        let item = snapshot.document.items.remove(at: sourceIndex)
        let destination = min(max(targetIndex, 0), snapshot.document.items.count)
        snapshot.document.items.insert(item, at: destination)
        self.snapshot = snapshot
        dragInteractionController.updateIndex(destination)
        rebuild(animated: true)
    }

    private func scheduleFolderHover(targetID: String) {
        guard folderReadyTargetID != targetID,
              pendingFolderTargetID != targetID else {
            return
        }
        cancelFolderHover()
        pendingFolderTargetID = targetID
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, pendingFolderTargetID == targetID else { return }
            pendingFolderTargetID = nil
            folderHoverWorkItem = nil
            folderReadyTargetID = targetID
            guard let target = tileLayers[targetID] else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(MotionSpec.dragLiftDuration)
            CATransaction.setAnimationTimingFunction(MotionSpec.entranceTiming)
            target.transform = CATransform3DMakeScale(
                DragVisual.folderTargetScale,
                DragVisual.folderTargetScale,
                1
            )
            CATransaction.commit()
        }
        folderHoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + DragTiming.folderDwell, execute: workItem)
    }

    private func cancelFolderHover() {
        folderHoverWorkItem?.cancel()
        folderHoverWorkItem = nil
        pendingFolderTargetID = nil
        if let targetID = folderReadyTargetID, let target = tileLayers[targetID] {
            CATransaction.begin()
            CATransaction.setAnimationDuration(MotionSpec.dragLiftDuration)
            CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
            target.transform = CATransform3DIdentity
            CATransaction.commit()
        }
        folderReadyTargetID = nil
    }

    private func scheduleEdgePagingIfNeeded(at point: CGPoint) {
        let delta: Int
        if point.x <= DragTiming.edgeInset {
            delta = -1
        } else if point.x >= bounds.width - DragTiming.edgeInset {
            delta = 1
        } else {
            cancelEdgePaging()
            return
        }
        guard let geometry,
              currentPage + delta >= 0,
              currentPage + delta < geometry.pageCount else {
            cancelEdgePaging()
            return
        }
        guard pendingEdgePageDelta != delta else { return }
        cancelEdgePaging()
        pendingEdgePageDelta = delta
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, pendingEdgePageDelta == delta else { return }
            pendingEdgePageDelta = nil
            edgePageWorkItem = nil
            moveToPage(currentPage + delta, animated: true)
            if let lastDragPoint {
                updateDragging(at: lastDragPoint)
            }
        }
        edgePageWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + DragTiming.edgeDwell, execute: workItem)
    }

    private func cancelEdgePaging() {
        edgePageWorkItem?.cancel()
        edgePageWorkItem = nil
        pendingEdgePageDelta = nil
    }

    private func cancelDragScheduling() {
        cancelReorderPreview()
        cancelFolderHover()
        cancelEdgePaging()
    }

    private func destinationFrame(for stableID: String, in document: LayoutDocument) -> CGRect? {
        guard let geometry,
              let rootLayer = layer,
              let index = document.items.firstIndex(where: { $0.stableID == stableID }) else {
            return nil
        }
        var frame = geometry.itemFrames[index % geometry.pageCapacity]
        let page = index / geometry.pageCapacity
        frame.origin.x += CGFloat(page - currentPage) * bounds.width
        return dragContentLayer.convert(frame, from: rootLayer)
    }

    private func finishDragging(at point: CGPoint) {
        guard case .dragging(let stableID, _, let pointerOffset) = dragInteractionController.state,
              let rootLayer = layer,
              let proxy = dragProxyLayer,
              var snapshot else {
            dragInteractionController.reset()
            return
        }
        let localPoint = dragContentLayer.convert(point, from: rootLayer)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        proxy.position = CGPoint(
            x: localPoint.x - pointerOffset.x,
            y: localPoint.y - pointerOffset.y
        )
        CATransaction.commit()

        let originalDocument = dragOriginalDocument ?? snapshot.document
        var finalDocument = snapshot.document
        var targetFrame: CGRect?
        if let targetID = folderReadyTargetID,
           let target = tileLayers[targetID],
           let folded = folderInteractionController.drop(
               draggedStableID: stableID,
               onto: targetID,
               in: finalDocument
           ) {
            targetFrame = target.convert(target.bounds, to: dragContentLayer)
            finalDocument = folded
        } else {
            targetFrame = destinationFrame(for: stableID, in: finalDocument)
        }
        finalDocument.sortMode = finalDocument.items != originalDocument.items
            ? .custom
            : originalDocument.sortMode
        let didMutate = finalDocument != originalDocument
        cancelDragScheduling()

        let completeDrop = { [weak self, weak proxy] in
            guard let self else { return }
            proxy?.removeFromSuperlayer()
            dragProxyLayer = nil
            dragInteractionController.reset()
            dragOriginalDocument = nil
            lastDragPoint = nil
            snapshot.document = finalDocument
            self.snapshot = snapshot
            rebuild(animated: false)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tileLayers[stableID]?.opacity = 1
            CATransaction.commit()
            if didMutate {
                delegate?.launchpadGridView(self, didMutate: finalDocument)
            }
        }

        guard let targetFrame else {
            completeDrop()
            return
        }
        let distance = hypot(proxy.position.x - targetFrame.midX, proxy.position.y - targetFrame.midY)
        let duration = min(
            max(CFTimeInterval(distance / DragTiming.dropPointsPerSecond), DragTiming.minimumDropDuration),
            DragTiming.maximumDropDuration
        )
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        CATransaction.setCompletionBlock(completeDrop)
        proxy.opacity = 1
        proxy.transform = CATransform3DIdentity
        proxy.bounds = CGRect(origin: .zero, size: targetFrame.size)
        proxy.position = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        CATransaction.commit()
    }

    private func moveToPage(_ page: Int, animated: Bool) {
        activeSwipeID = nil
        activeSwipeTargetPage = nil
        let pageCount = geometry?.pageCount ?? 1
        currentPage = min(max(page, 0), pageCount - 1)
        pageIndicatorLayer.select(page: currentPage)
        setPageOffset(-CGFloat(currentPage) * bounds.width, animated: animated)
        updateSelectionFrame(animated: animated)
        if editModeController.isEditing {
            updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
        }
    }

    private func setPageOffset(
        _ offset: CGFloat,
        animated: Bool
    ) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(MotionSpec.pageSnapDuration)
            CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        } else {
            CATransaction.setDisableActions(true)
        }
        var frame = pagesLayer.frame
        frame.origin.x = offset
        pagesLayer.frame = frame
        CATransaction.commit()
    }

    private func updateSelectionFrame(animated: Bool) {
        guard selectionVisible,
              let selectedItemIndex,
              let geometry,
              selectedItemIndex / geometry.pageCapacity == currentPage else {
            selectionLayer.isHidden = true
            return
        }
        let position = selectedItemIndex % geometry.pageCapacity
        guard position < geometry.itemFrames.count else { return }
        let itemFrame = geometry.itemFrames[position]
        let target = CGRect(
            x: itemFrame.minX + (itemFrame.width - LaunchpadMetrics.iconPointSize) / 2 - 6,
            y: itemFrame.minY - 6,
            width: LaunchpadMetrics.iconPointSize + 12,
            height: LaunchpadMetrics.iconPointSize + 12
        )
        selectionLayer.isHidden = false
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? MotionSpec.layoutDuration : 0)
        CATransaction.setAnimationTimingFunction(MotionSpec.settleTiming)
        selectionLayer.frame = target
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if editModeController.isEditing, let application = applicationForDeleteBadge(at: point) {
            delegate?.launchpadGridView(self, requestedRemoval: application)
            return
        }
        if pageIndicatorLayer.frame.contains(point) {
            let local = CGPoint(
                x: point.x - pageIndicatorLayer.frame.minX,
                y: point.y - pageIndicatorLayer.frame.minY
            )
            if let page = pageIndicatorLayer.pageIndex(at: local) {
                moveToPage(page, animated: true)
                return
            }
        }
        pressedItemIndex = itemIndex(at: point)
        if let pressedItemIndex {
            editModeController.beginPress()
            selectedItemIndex = pressedItemIndex
            selectionVisible = false
            setPressed(true, at: pressedItemIndex)
            dragInteractionController.beginPress(index: pressedItemIndex, point: point)
            if allowsLayoutMutation, !editModeController.isEditing {
                editModeController.scheduleLongPress { [weak self] in
                    guard let self, let pressedItemIndex = self.pressedItemIndex else { return }
                    self.setPressed(false, at: pressedItemIndex)
                    self.enterEditMode()
                }
            }
        } else if editModeController.isEditing {
            exitEditMode()
        } else {
            delegate?.launchpadGridViewDidClickBackground(self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard allowsLayoutMutation else { return }
        let point = convert(event.locationInWindow, from: nil)
        if dragInteractionController.shouldBeginDragging(at: point), let pressedItemIndex {
            editModeController.cancelLongPress()
            setPressed(false, at: pressedItemIndex)
            beginDragging(index: pressedItemIndex, point: point)
        }
        if case .dragging = dragInteractionController.state {
            updateDragging(at: point)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let consumedLongPress = editModeController.endPress()
        let point = convert(event.locationInWindow, from: nil)
        if case .dragging = dragInteractionController.state {
            pressedItemIndex = nil
            finishDragging(at: point)
            return
        }
        let releasedIndex = itemIndex(at: point)
        if let pressedItemIndex { setPressed(false, at: pressedItemIndex) }
        defer {
            pressedItemIndex = nil
            dragInteractionController.reset()
        }
        guard !consumedLongPress else { return }
        guard let pressedItemIndex,
              releasedIndex == pressedItemIndex,
              let snapshot,
              pressedItemIndex < snapshot.document.items.count else { return }
        switch snapshot.document.items[pressedItemIndex] {
        case .application(let identity):
            if let application = snapshot.application(for: identity) {
                delegate?.launchpadGridView(self, didActivate: application)
            }
        case .folder(let folder):
            delegate?.launchpadGridView(self, didOpen: folder)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard handlePageScroll(event) else {
            super.scrollWheel(with: event)
            return
        }
    }

    @discardableResult
    func handlePageScroll(_ event: NSEvent) -> Bool {
        guard let geometry, geometry.pageCount > 1 else { return false }
        if !event.hasPreciseScrollingDeltas {
            let rawDelta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX
                : event.scrollingDeltaY
            guard rawDelta != .zero else { return false }
            guard event.timestamp - lastDiscretePageTimestamp >= PageScroll.discretePageInterval else { return true }
            lastDiscretePageTimestamp = event.timestamp
            movePage(by: rawDelta < 0 ? 1 : -1)
            return true
        }

        if activeSwipeID != nil {
            guard event.phase.contains(.began) else { return true }
            commitActiveSwipeForInterruption(pageCount: geometry.pageCount)
        }
        guard NSEvent.isSwipeTrackingFromScrollEventsEnabled,
              event.phase.contains(.began) || event.phase.contains(.changed) else {
            return false
        }
        trackSystemSwipe(with: event, pageCount: geometry.pageCount)
        return true
    }

    private func commitActiveSwipeForInterruption(pageCount: Int) {
        let targetPage = min(max(activeSwipeTargetPage ?? currentPage, 0), pageCount - 1)
        activeSwipeID = nil
        activeSwipeTargetPage = nil
        currentPage = targetPage
        setPageOffset(-CGFloat(currentPage) * bounds.width, animated: false)
        pageIndicatorLayer.select(page: currentPage)
        updateSelectionFrame(animated: false)
        if editModeController.isEditing {
            updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
        }
    }

    private func trackSystemSwipe(with event: NSEvent, pageCount: Int) {
        pagesLayer.removeAllAnimations()
        setPageOffset(-CGFloat(currentPage) * bounds.width, animated: false)

        let swipeID = UUID()
        activeSwipeID = swipeID
        let startPage = currentPage
        activeSwipeTargetPage = startPage
        let pageWidth = max(bounds.width, 1)
        let minimumAmount: CGFloat = startPage < pageCount - 1 ? -1 : 0
        let maximumAmount: CGFloat = startPage > 0 ? 1 : 0

        event.trackSwipeEvent(
            options: [.lockDirection, .clampGestureAmount],
            dampenAmountThresholdMin: minimumAmount,
            max: maximumAmount
        ) { [weak self] gestureAmount, _, isComplete, stop in
            guard let self, activeSwipeID == swipeID else {
                stop.pointee = true
                return
            }

            let translation = gestureAmount * pageWidth
            setPageOffset(-CGFloat(startPage) * pageWidth + translation, animated: false)
            pageIndicatorLayer.showTransition(
                from: startPage,
                translation: translation,
                pageWidth: pageWidth
            )

            let interruptionDelta: Int
            if gestureAmount <= -PageScroll.continuationCommitProgress {
                interruptionDelta = 1
            } else if gestureAmount >= PageScroll.continuationCommitProgress {
                interruptionDelta = -1
            } else {
                interruptionDelta = 0
            }
            activeSwipeTargetPage = min(max(startPage + interruptionDelta, 0), pageCount - 1)

            guard isComplete else { return }
            currentPage = min(
                max(startPage - Int(gestureAmount.rounded()), 0),
                pageCount - 1
            )
            setPageOffset(-CGFloat(currentPage) * pageWidth, animated: false)
            pageIndicatorLayer.select(page: currentPage)
            updateSelectionFrame(animated: false)
            if editModeController.isEditing {
                updateEditAppearance(displayScale: window?.backingScaleFactor ?? 2)
            }
            activeSwipeID = nil
            activeSwipeTargetPage = nil
        }
    }
}

private enum PageScroll {
    static let discretePageInterval: TimeInterval = 0.32
    static let continuationCommitProgress: CGFloat = 0.5
}

private enum EditVisual {
    static let rotation: CGFloat = 0.022
    static let duration: CFTimeInterval = 0.14
}

private enum DragVisual {
    static let scale: CGFloat = 1.1
    static let opacity: Float = 0.94
    static let overlayZPosition: CGFloat = 50
    static let zPosition: CGFloat = 100
    static let folderTargetScale: CGFloat = 1.08
    static let folderActivationInset: CGFloat = 18
}

private enum DragTiming {
    static let reorderDwell: TimeInterval = 0.1
    static let folderDwell: TimeInterval = 0.5
    static let edgeDwell: TimeInterval = 0.62
    static let edgeInset: CGFloat = 38
    static let dropPointsPerSecond: CGFloat = 1_800
    static let minimumDropDuration: CFTimeInterval = 0.12
    static let maximumDropDuration: CFTimeInterval = 0.24
}
