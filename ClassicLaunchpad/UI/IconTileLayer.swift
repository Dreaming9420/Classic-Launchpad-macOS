import AppKit
import QuartzCore

final class IconTileLayer: CALayer {
    private let iconLayer = CALayer()
    private let titleLayer = CATextLayer()
    private(set) var representedID = ""

    override init() {
        super.init()
        isGeometryFlipped = true
        addSublayer(iconLayer)
        addSublayer(titleLayer)

        iconLayer.contentsGravity = .resizeAspect
        iconLayer.shadowColor = NSColor.black.cgColor
        iconLayer.shadowOpacity = 0.34
        iconLayer.shadowRadius = 3
        iconLayer.shadowOffset = CGSize(width: 0, height: 2)

        titleLayer.alignmentMode = .center
        titleLayer.truncationMode = .end
        titleLayer.isWrapped = false
        titleLayer.foregroundColor = LaunchpadColors.title.cgColor
        titleLayer.shadowColor = LaunchpadColors.titleShadow.cgColor
        titleLayer.shadowOpacity = 0.9
        titleLayer.shadowRadius = 1.5
        titleLayer.shadowOffset = CGSize(width: 0, height: 1)
        titleLayer.font = NSFont.systemFont(ofSize: LaunchpadMetrics.titleFontSize, weight: .medium)
        titleLayer.fontSize = LaunchpadMetrics.titleFontSize
        titleLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    override init(layer: Any) {
        if let source = layer as? IconTileLayer {
            representedID = source.representedID
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        with application: InstalledApplication,
        iconRepository: IconRepository,
        displayScale: CGFloat
    ) {
        representedID = LayoutItem.application(application.identity).stableID
        titleLayer.string = application.displayName
        titleLayer.contentsScale = displayScale
        iconLayer.contentsScale = displayScale
        iconLayer.contents = nil

        let expectedID = representedID
        iconRepository.loadIcon(
            for: application,
            pointSize: LaunchpadMetrics.iconPointSize,
            scale: displayScale
        ) { [weak self] image in
            guard let self, representedID == expectedID else { return }
            iconLayer.contents = image
        }
    }

    func makeDragRepresentation() -> IconTileLayer {
        let representation = IconTileLayer()
        representation.representedID = representedID
        representation.bounds = bounds
        representation.iconLayer.contents = iconLayer.contents
        representation.iconLayer.contentsScale = iconLayer.contentsScale
        representation.titleLayer.string = titleLayer.string
        representation.titleLayer.contentsScale = titleLayer.contentsScale
        representation.setNeedsLayout()
        representation.layoutIfNeeded()
        return representation
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        iconLayer.frame = CGRect(
            x: (bounds.width - LaunchpadMetrics.iconPointSize) / 2,
            y: LaunchpadMetrics.titleHeight + LaunchpadMetrics.titleTopSpacing,
            width: LaunchpadMetrics.iconPointSize,
            height: LaunchpadMetrics.iconPointSize
        )
        titleLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: LaunchpadMetrics.titleHeight
        )
    }

    func setPressed(_ pressed: Bool) {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = presentation()?.value(forKeyPath: "transform.scale") ?? 1
        animation.toValue = pressed ? MotionSpec.pressScale : 1
        animation.duration = MotionSpec.pressDuration
        animation.timingFunction = pressed ? MotionSpec.exitTiming : MotionSpec.entranceTiming
        transform = pressed
            ? CATransform3DMakeScale(MotionSpec.pressScale, MotionSpec.pressScale, 1)
            : CATransform3DIdentity
        add(animation, forKey: "press")
    }

    func prepareForReuse() {
        representedID = ""
        iconLayer.contents = nil
        titleLayer.string = nil
        removeAllAnimations()
        transform = CATransform3DIdentity
    }
}
