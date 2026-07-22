import AppKit
import QuartzCore

final class FolderTileLayer: CALayer {
    private let backgroundLayer = CALayer()
    private let titleLayer = CATextLayer()
    private var previewLayers: [CALayer] = []
    private(set) var representedID = ""

    override init() {
        super.init()
        isGeometryFlipped = true
        addSublayer(backgroundLayer)
        addSublayer(titleLayer)
        backgroundLayer.backgroundColor = NSColor.white.withAlphaComponent(0.16).cgColor
        backgroundLayer.cornerRadius = LaunchpadMetrics.iconCornerRadius
        backgroundLayer.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        backgroundLayer.borderWidth = 0.5
        backgroundLayer.shadowColor = NSColor.black.cgColor
        backgroundLayer.shadowOpacity = 0.25
        backgroundLayer.shadowRadius = 3
        backgroundLayer.shadowOffset = CGSize(width: 0, height: 2)

        titleLayer.alignmentMode = .center
        titleLayer.truncationMode = .end
        titleLayer.foregroundColor = LaunchpadColors.title.cgColor
        titleLayer.shadowColor = LaunchpadColors.titleShadow.cgColor
        titleLayer.shadowOpacity = 0.9
        titleLayer.shadowRadius = 1.5
        titleLayer.shadowOffset = CGSize(width: 0, height: 1)
        titleLayer.font = NSFont.systemFont(ofSize: LaunchpadMetrics.titleFontSize, weight: .medium)
        titleLayer.fontSize = LaunchpadMetrics.titleFontSize
    }

    override init(layer: Any) {
        if let source = layer as? FolderTileLayer {
            representedID = source.representedID
        }
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        with folder: FolderLayout,
        applicationsByKey: [String: InstalledApplication],
        iconRepository: IconRepository,
        displayScale: CGFloat
    ) {
        representedID = LayoutItem.folder(folder).stableID
        titleLayer.string = folder.name
        titleLayer.contentsScale = displayScale

        previewLayers.forEach { $0.removeFromSuperlayer() }
        previewLayers.removeAll()
        let previewApplications = folder.applications.prefix(FolderPreview.maximumIcons).compactMap {
            applicationsByKey[$0.stableKey]
        }

        for (index, application) in previewApplications.enumerated() {
            let previewLayer = CALayer()
            previewLayer.contentsGravity = .resizeAspect
            previewLayer.contentsScale = displayScale
            backgroundLayer.addSublayer(previewLayer)
            previewLayers.append(previewLayer)
            let expectedID = representedID
            iconRepository.loadIcon(
                for: application,
                pointSize: FolderPreview.iconPointSize,
                scale: displayScale
            ) { [weak self, weak previewLayer] image in
                guard let self, representedID == expectedID else { return }
                previewLayer?.contents = image
            }
            previewLayer.frame = previewFrame(at: index)
        }
    }

    func makeDragRepresentation() -> FolderTileLayer {
        let representation = FolderTileLayer()
        representation.representedID = representedID
        representation.bounds = bounds
        representation.titleLayer.string = titleLayer.string
        representation.titleLayer.contentsScale = titleLayer.contentsScale

        for previewLayer in previewLayers {
            let representationPreview = CALayer()
            representationPreview.contents = previewLayer.contents
            representationPreview.contentsGravity = previewLayer.contentsGravity
            representationPreview.contentsScale = previewLayer.contentsScale
            representation.backgroundLayer.addSublayer(representationPreview)
            representation.previewLayers.append(representationPreview)
        }
        representation.setNeedsLayout()
        representation.layoutIfNeeded()
        return representation
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        backgroundLayer.frame = CGRect(
            x: (bounds.width - LaunchpadMetrics.iconPointSize) / 2,
            y: LaunchpadMetrics.titleHeight + LaunchpadMetrics.titleTopSpacing,
            width: LaunchpadMetrics.iconPointSize,
            height: LaunchpadMetrics.iconPointSize
        )
        for (index, previewLayer) in previewLayers.enumerated() {
            previewLayer.frame = previewFrame(at: index)
        }
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
        transform = pressed
            ? CATransform3DMakeScale(MotionSpec.pressScale, MotionSpec.pressScale, 1)
            : CATransform3DIdentity
        add(animation, forKey: "press")
    }

    private func previewFrame(at index: Int) -> CGRect {
        let column = index % FolderPreview.columns
        let row = index / FolderPreview.columns
        let occupiedWidth = CGFloat(FolderPreview.columns) * FolderPreview.iconPointSize
            + CGFloat(FolderPreview.columns - 1) * FolderPreview.spacing
        let inset = (LaunchpadMetrics.iconPointSize - occupiedWidth) / 2
        return CGRect(
            x: inset + CGFloat(column) * (FolderPreview.iconPointSize + FolderPreview.spacing),
            y: inset + CGFloat(row) * (FolderPreview.iconPointSize + FolderPreview.spacing),
            width: FolderPreview.iconPointSize,
            height: FolderPreview.iconPointSize
        )
    }
}

private enum FolderPreview {
    static let columns = 3
    static let maximumIcons = 9
    static let iconPointSize: CGFloat = 22
    static let spacing: CGFloat = 4
}
