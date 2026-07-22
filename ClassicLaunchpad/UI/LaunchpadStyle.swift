import AppKit
import QuartzCore

enum LaunchpadMetrics {
    static let backgroundScale: CGFloat = 1.035
    static let backgroundBlurRadius: CGFloat = 22
    static let backgroundDimOpacity: Float = 0.28
    static let searchTopOffset: CGFloat = 64
    static let searchWidth: CGFloat = 220
    static let searchHeight: CGFloat = 32
    static let pageIndicatorBottomOffset: CGFloat = 54
    static let iconPointSize: CGFloat = 96
    static let iconCornerRadius: CGFloat = 20
    static let itemWidth: CGFloat = 148
    static let itemHeight: CGFloat = 132
    static let titleTopSpacing: CGFloat = 8
    static let titleFontSize: CGFloat = 13
    static let titleHeight: CGFloat = 19
    static let minimumHorizontalMargin: CGFloat = 72
    static let gridTopInset: CGFloat = 128
    static let gridBottomInset: CGFloat = 94
}

enum MotionSpec {
    static let entranceDuration: CFTimeInterval = 0.32
    static let exitDuration: CFTimeInterval = 0.24
    static let pressDuration: CFTimeInterval = 0.09
    static let pressScale: CGFloat = 0.94
    static let pageSnapDuration: CFTimeInterval = 0.3
    static let layoutDuration: CFTimeInterval = 0.28
    static let folderDuration: CFTimeInterval = 0.34
    static let dragLiftDuration: CFTimeInterval = 0.16
    static let reducedMotionDuration: CFTimeInterval = 0.14

    static let entranceTiming = CAMediaTimingFunction(controlPoints: 0.2, 0.82, 0.2, 1)
    static let exitTiming = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.8, 0.2)
    static let settleTiming = CAMediaTimingFunction(controlPoints: 0.18, 0.72, 0.22, 1)
}

enum LaunchpadColors {
    static let dim = NSColor.black.withAlphaComponent(CGFloat(LaunchpadMetrics.backgroundDimOpacity))
    static let title = NSColor.white
    static let titleShadow = NSColor.black.withAlphaComponent(0.8)
    static let searchFill = NSColor.black.withAlphaComponent(0.2)
    static let pageDot = NSColor.white.withAlphaComponent(0.42)
    static let selectedPageDot = NSColor.white.withAlphaComponent(0.92)
}
