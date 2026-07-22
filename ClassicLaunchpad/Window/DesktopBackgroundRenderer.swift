import AppKit
import CoreImage

final class DesktopBackgroundRenderer {
    private let context = CIContext(options: [.cacheIntermediates: true])

    func render(for screen: NSScreen, completion: @escaping (CGImage?) -> Void) {
        let imageURL = NSWorkspace.shared.desktopImageURL(for: screen)
        let pointSize = screen.frame.size
        let scale = screen.backingScaleFactor

        DispatchQueue.global(qos: .userInitiated).async { [context] in
            guard
                let imageURL,
                let image = NSImage(contentsOf: imageURL),
                let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let outputSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
            let sourceSize = CGSize(width: source.width, height: source.height)
            let fillScale = max(outputSize.width / sourceSize.width, outputSize.height / sourceSize.height)
            let scaledSize = CGSize(width: sourceSize.width * fillScale, height: sourceSize.height * fillScale)
            let offset = CGVector(
                dx: (outputSize.width - scaledSize.width) / 2,
                dy: (outputSize.height - scaledSize.height) / 2
            )

            let transform = CGAffineTransform(translationX: offset.dx, y: offset.dy)
                .scaledBy(x: fillScale, y: fillScale)
            let extent = CGRect(origin: .zero, size: outputSize)
            let sourceImage = CIImage(cgImage: source).transformed(by: transform).clampedToExtent()
            let blurred = sourceImage
                .applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: LaunchpadMetrics.backgroundBlurRadius * scale
                ])
                .cropped(to: extent)
            let output = context.createCGImage(blurred, from: extent)

            DispatchQueue.main.async { completion(output) }
        }
    }
}
