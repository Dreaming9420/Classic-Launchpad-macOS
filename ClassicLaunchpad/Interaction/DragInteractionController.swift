import AppKit

final class DragInteractionController {
    enum State {
        case idle
        case pressing(index: Int, point: CGPoint)
        case dragging(stableID: String, index: Int, pointerOffset: CGPoint)
    }

    private(set) var state: State = .idle

    func beginPress(index: Int, point: CGPoint) {
        state = .pressing(index: index, point: point)
    }

    func shouldBeginDragging(at point: CGPoint) -> Bool {
        guard case .pressing(_, let origin) = state else { return false }
        return hypot(point.x - origin.x, point.y - origin.y) >= DragThreshold.minimumDistance
    }

    func beginDragging(stableID: String, index: Int, pointerOffset: CGPoint) {
        state = .dragging(stableID: stableID, index: index, pointerOffset: pointerOffset)
    }

    func updateIndex(_ index: Int) {
        guard case .dragging(let stableID, _, let pointerOffset) = state else { return }
        state = .dragging(stableID: stableID, index: index, pointerOffset: pointerOffset)
    }

    func reset() {
        state = .idle
    }
}

private enum DragThreshold {
    static let minimumDistance: CGFloat = 7
}
