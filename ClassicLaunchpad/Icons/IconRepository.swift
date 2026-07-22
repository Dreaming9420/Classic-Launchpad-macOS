import AppKit
import OSLog

final class IconRepository {
    private enum CacheLimit {
        static let memoryBytes = 96 * 1_024 * 1_024
        static let itemCount = 512
    }

    private static let logger = Logger(
        subsystem: "com.example.ClassicLaunchpad",
        category: "IconRepository"
    )

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let workQueue = DispatchQueue(
        label: "com.example.ClassicLaunchpad.icon-cache",
        qos: .userInitiated,
        attributes: .concurrent
    )

    init() {
        let applicationSupport = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = applicationSupport
            .appendingPathComponent("QitaiClassicLaunchpad", isDirectory: true)
            .appendingPathComponent("Icons", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.totalCostLimit = CacheLimit.memoryBytes
        memoryCache.countLimit = CacheLimit.itemCount
    }

    func loadIcon(
        for application: InstalledApplication,
        pointSize: CGFloat,
        scale: CGFloat,
        completion: @escaping (NSImage?) -> Void
    ) {
        let key = cacheKey(for: application, pointSize: pointSize, scale: scale)
        if let cached = memoryCache.object(forKey: key as NSString) {
            completion(cached)
            return
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            let diskURL = cacheDirectory.appendingPathComponent(key).appendingPathExtension("png")
            if let data = try? Data(contentsOf: diskURL), let image = NSImage(data: data) {
                let cost = Int(image.size.width * image.size.height * 4)
                memoryCache.setObject(image, forKey: key as NSString, cost: cost)
                DispatchQueue.main.async { completion(image) }
                return
            }

            let source = NSWorkspace.shared.icon(forFile: application.url.path)
            guard let rendered = render(source, pointSize: pointSize, scale: scale) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            memoryCache.setObject(
                rendered.image,
                forKey: key as NSString,
                cost: rendered.pixelCost
            )
            do {
                try rendered.pngData.write(to: diskURL, options: .atomic)
            } catch {
                Self.logger.error("Unable to persist an icon cache entry: \(error.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async { completion(rendered.image) }
        }
    }

    func removeAllMemoryObjects() {
        memoryCache.removeAllObjects()
    }

    private func render(
        _ source: NSImage,
        pointSize: CGFloat,
        scale: CGFloat
    ) -> (image: NSImage, pngData: Data, pixelCost: Int)? {
        let pixels = max(Int((pointSize * scale).rounded(.up)), 1)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        representation.size = CGSize(width: pointSize, height: pointSize)
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(
            in: CGRect(x: 0, y: 0, width: pointSize, height: pointSize),
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            return nil
        }
        let image = NSImage(size: CGSize(width: pointSize, height: pointSize))
        image.addRepresentation(representation)
        return (image, pngData, pixels * pixels * 4)
    }

    private func cacheKey(
        for application: InstalledApplication,
        pointSize: CGFloat,
        scale: CGFloat
    ) -> String {
        let source = "\(application.identity.stableKey)|\(application.versionFingerprint)|\(pointSize)|\(scale)"
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
