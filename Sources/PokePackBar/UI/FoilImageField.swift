import AppKit
import CryptoKit
import SwiftUI
import Vision

/// Image-guided approximation, NOT a scan of the printing's physical emboss.
/// Artwork gradients orient local relief so different cards no longer share
/// two synthetic spiral centres. The material still owns palette/sheet texture.
final class FoilImageField: @unchecked Sendable {
    let width = 144
    let height = 201
    let key: String
    let luminance: [Double]
    let direction: [Double]
    let edge: [Double]

    init?(image: CGImage) {
        let width = self.width
        let height = self.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        key = OpeningRules.digest(Data(rgba))
        let count = width * height
        var light = [Double](repeating: 0, count: count)
        for i in 0..<count {
            light[i] = (Double(rgba[i * 4]) * 0.2126 + Double(rgba[i * 4 + 1]) * 0.7152
                        + Double(rgba[i * 4 + 2]) * 0.0722) / 255
        }
        var directions = [Double](repeating: 0, count: count)
        var edges = [Double](repeating: 0, count: count)
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let p = y * width + x
                let dx = light[p + 2] + light[p + 1] - light[p - 1] - light[p - 2]
                let dy = light[p + 2 * width] + light[p + width] - light[p - width] - light[p - 2 * width]
                directions[p] = atan2(dy, dx) + .pi * 0.5
                edges[p] = min(1, hypot(dx, dy) * 1.7)
            }
        }
        luminance = light
        direction = directions
        edge = edges
    }

    func sample(x: Double, y: Double) -> (light: Double, direction: Double, edge: Double) {
        let i = min(height - 1, max(0, Int(y * Double(height)))) * width
            + min(width - 1, max(0, Int(x * Double(width))))
        return (luminance[i], direction[i], edge[i])
    }
}

@MainActor
enum FoilImageFieldCache {
    private final class Entry {
        let source: NSImage
        let field: FoilImageField
        init(source: NSImage, field: FoilImageField) { self.source = source; self.field = field }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let value = NSCache<NSString, Entry>(); value.countLimit = 16; return value
    }()
    static func field(_ image: NSImage?, cardID: String) -> FoilImageField? {
        guard let image else { return nil }
        let key = "\(cardID)#\(ObjectIdentifier(image))" as NSString
        if let cached = cache.object(forKey: key) { return cached.field }
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let field = FoilImageField(image: cg) else { return nil }
        // Retain the source while its identity is used as a key; object addresses
        // must not be recycled into a stale field after an HD image replacement.
        cache.setObject(Entry(source: image, field: field), forKey: key)
        return field
    }
}

@MainActor
struct ImageGuidedFoilRelief: View {
    let cardID: String
    let preloaded: NSImage?
    let material: FoilReliefMaterial
    let seed: UInt64
    let tilt: TiltVector
    @State private var loaded: NSImage?
    @State private var loadedID: String?
    var body: some View {
        FoilReliefLayer(material: material, seed: seed, tilt: tilt,
            imageField: FoilImageFieldCache.field(loadedID == cardID ? loaded : preloaded, cardID: cardID))
            .task(id: cardID) {
                guard preloaded == nil else { return }
                let image = await CardImageLoader.image(cardID: cardID, hires: true)
                guard !Task.isCancelled else { return }
                loaded = image; loadedID = cardID
            }
    }
}

/// Subject segmentation is derived from the actual illustration, not an oval.
/// Vision's mask is still an estimated art silhouette, not a measured foil mask.
@MainActor
enum ArtworkMaskCache {
    private final class Entry {
        let source: NSImage
        let image: CGImage
        init(_ image: CGImage, source: NSImage) { self.image = image; self.source = source }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let value = NSCache<NSString, Entry>(); value.countLimit = 32; return value
    }()
    static func key(cardID: String, source: NSImage?, art: CGRect) -> String {
        let identity = source.map { String(describing: ObjectIdentifier($0)) } ?? "missing"
        return "\(cardID)#\(identity)#\(art)"
    }
    static func mask(key: String) -> CGImage? { cache.object(forKey: key as NSString)?.image }
    static func prepare(cardID: String, source: NSImage, art: CGRect) async -> CGImage? {
        // Registered cards use immutable, source-hash-bound paths below. Never
        // silently replace an absent/stale reviewed path with fresh segmentation.
        guard !FoilSubjectMasks.requiresRegisteredMask(cardID: cardID) else { return nil }
        let cacheKey = key(cardID: cardID, source: source, art: art) as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached.image }
        guard let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let crop = CGRect(x: art.minX * Double(cg.width), y: art.minY * Double(cg.height),
                          width: art.width * Double(cg.width), height: art.height * Double(cg.height))
        guard let artwork = cg.cropping(to: crop) else { return nil }
        let result = await Task.detached(priority: .utility) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: artwork)
            guard (try? handler.perform([request])) != nil,
                  let observation = request.results?.first, !observation.allInstances.isEmpty,
                  let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances,
                                                                           from: handler) else { return Optional<CGImage>.none }
            let image = CIImage(cvPixelBuffer: buffer).applyingFilter("CIMaskToAlpha")
            return CIContext().createCGImage(image, from: image.extent)
        }.value
        // Failed segmentation is retryable; don't permanently cache a miss.
        if let result { cache.setObject(Entry(result, source: source), forKey: cacheKey) }
        return result
    }
}

@MainActor
struct ArtworkFoilMask: View {
    let cardID: String
    let preloaded: NSImage?
    let coverage: FoilCoverage
    let art: CGRect // normalized artwork bounds
    var requirePreparedMask = false
    @State private var mask: CGImage?
    @State private var maskKey: String?

    private var key: String { ArtworkMaskCache.key(cardID: cardID, source: preloaded, art: art) }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: art.minX * size.width, y: art.minY * size.height,
                              width: art.width * size.width, height: art.height * size.height)
            let artwork = FoilGeometry.illustrationPath(cardID: cardID, in: size) ?? Path(rect)
            // Curve/badge cutouts are in scan coordinates just like the crop.
            var artContext = context
            artContext.clip(to: artwork)
            if FoilSubjectMasks.requiresRegisteredMask(cardID: cardID) {
                if let subject = FoilSubjectMasks.subjectPath(cardID: cardID, in: size) {
                    if coverage == .artBackground {
                        artContext.fill(artwork, with: .color(.white))
                        artContext.blendMode = .destinationOut
                    }
                    artContext.fill(subject, with: .color(.white), style: FillStyle(eoFill: true))
                }
                if coverage == .artSubjectAndBorder {
                    context.fill(FoilSubjectMasks.borderPath(cardID: cardID, in: size),
                                 with: .color(.white), style: FillStyle(eoFill: true))
                }
                return
            }
            let preparedMask = (maskKey == key ? mask : nil) ?? ArtworkMaskCache.mask(key: key)
            // New background substrate must never flash over opaque Pokémon
            // ink while asynchronous foreground separation is still loading.
            if requirePreparedMask && preparedMask == nil { return }
            if coverage == .artBackground { artContext.fill(artwork, with: .color(.white)) }
            if let mask = preparedMask {
                if coverage == .artBackground { artContext.blendMode = .destinationOut }
                artContext.draw(Image(decorative: mask, scale: 1), in: rect)
            }
            if coverage == .artSubjectAndBorder {
                context.blendMode = .normal
                context.stroke(Path(roundedRect: CGRect(origin: .zero, size: size)
                    .insetBy(dx: size.width * 0.018, dy: size.width * 0.018), cornerRadius: size.width * 0.045),
                    with: .color(.white), lineWidth: size.width * 0.055)
            }
        }
        .task(id: key) {
            guard !FoilSubjectMasks.requiresRegisteredMask(cardID: cardID) else { return }
            let requested = key
            let source: NSImage?
            if let preloaded { source = preloaded }
            else { source = await CardImageLoader.image(cardID: cardID, hires: true) }
            guard !Task.isCancelled, let source else { return }
            let result = await ArtworkMaskCache.prepare(cardID: cardID, source: source, art: art)
            guard !Task.isCancelled, requested == key else { return }
            mask = result; maskKey = requested
        }
    }
}
