import AppKit
import QuartzCore

final class DeleteBadgeLayer: CALayer {
    private let symbolLayer = CATextLayer()

    override init() {
        super.init()
        backgroundColor = NSColor.white.withAlphaComponent(0.94).cgColor
        borderColor = NSColor.black.withAlphaComponent(0.24).cgColor
        borderWidth = 0.5
        cornerRadius = DeleteBadge.size / 2
        shadowColor = NSColor.black.cgColor
        shadowOpacity = 0.28
        shadowRadius = 2
        shadowOffset = CGSize(width: 0, height: 1)

        symbolLayer.string = "×"
        symbolLayer.alignmentMode = .center
        symbolLayer.foregroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        symbolLayer.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        symbolLayer.fontSize = 15
        symbolLayer.frame = CGRect(x: 0, y: 1, width: DeleteBadge.size, height: DeleteBadge.size)
        addSublayer(symbolLayer)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(displayScale: CGFloat) {
        contentsScale = displayScale
        symbolLayer.contentsScale = displayScale
    }
}

enum DeleteBadge {
    static let size: CGFloat = 22
}
