import AppKit
import QuartzCore

final class PageIndicatorLayer: CALayer {
    private var dots: [CALayer] = []
    private(set) var pageCount = 1
    private(set) var selectedPage = 0

    override init() {
        super.init()
    }

    override init(layer: Any) {
        if let source = layer as? PageIndicatorLayer {
            pageCount = source.pageCount
            selectedPage = source.selectedPage
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(pageCount: Int, selectedPage: Int, displayScale: CGFloat) {
        self.pageCount = max(pageCount, 1)
        self.selectedPage = min(max(selectedPage, 0), self.pageCount - 1)

        while dots.count < self.pageCount {
            let dot = CALayer()
            addSublayer(dot)
            dots.append(dot)
        }
        while dots.count > self.pageCount {
            dots.removeLast().removeFromSuperlayer()
        }
        dots.forEach { $0.contentsScale = displayScale }
        updateColors()
        setNeedsLayout()
    }

    func select(page: Int) {
        selectedPage = min(max(page, 0), pageCount - 1)
        updateColors()
    }

    func showTransition(from page: Int, translation: CGFloat, pageWidth: CGFloat) {
        selectedPage = min(max(page, 0), pageCount - 1)
        let targetPage = min(
            max(selectedPage + (translation < 0 ? 1 : -1), 0),
            pageCount - 1
        )
        let progress = min(abs(translation) / max(pageWidth, 1), 1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, dot) in dots.enumerated() {
            let alpha: CGFloat
            if index == selectedPage {
                alpha = Indicator.selectedAlpha
                    - (Indicator.selectedAlpha - Indicator.defaultAlpha) * progress
            } else if index == targetPage {
                alpha = Indicator.defaultAlpha
                    + (Indicator.selectedAlpha - Indicator.defaultAlpha) * progress
            } else {
                alpha = Indicator.defaultAlpha
            }
            dot.backgroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
        }
        CATransaction.commit()
    }

    func pageIndex(at point: CGPoint) -> Int? {
        dots.firstIndex { $0.frame.insetBy(dx: -4, dy: -4).contains(point) }
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        let width = CGFloat(pageCount) * Indicator.dotSize
            + CGFloat(max(pageCount - 1, 0)) * Indicator.spacing
        let originX = (bounds.width - width) / 2
        for (index, dot) in dots.enumerated() {
            dot.frame = CGRect(
                x: originX + CGFloat(index) * (Indicator.dotSize + Indicator.spacing),
                y: (bounds.height - Indicator.dotSize) / 2,
                width: Indicator.dotSize,
                height: Indicator.dotSize
            )
            dot.cornerRadius = Indicator.dotSize / 2
        }
    }

    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, dot) in dots.enumerated() {
            dot.backgroundColor = index == selectedPage
                ? LaunchpadColors.selectedPageDot.cgColor
                : LaunchpadColors.pageDot.cgColor
        }
        CATransaction.commit()
    }
}

private enum Indicator {
    static let dotSize: CGFloat = 6
    static let spacing: CGFloat = 8
    static let defaultAlpha: CGFloat = 0.42
    static let selectedAlpha: CGFloat = 0.92
}
