import Foundation

enum GridNavigationDirection {
    case left
    case right
    case up
    case down
}

final class KeyboardNavigationController {
    func destination(
        from current: Int?,
        direction: GridNavigationDirection,
        columns: Int,
        itemCount: Int
    ) -> Int? {
        guard itemCount > 0 else { return nil }
        let source = min(max(current ?? 0, 0), itemCount - 1)
        let candidate: Int
        switch direction {
        case .left:
            candidate = source - 1
        case .right:
            candidate = source + 1
        case .up:
            candidate = source - columns
        case .down:
            candidate = source + columns
        }
        return min(max(candidate, 0), itemCount - 1)
    }
}
