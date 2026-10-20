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
    let meanLuminance: Double

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
        meanLuminance = light.reduce(0, +) / Double(count)
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
            imageField: FoilImageFieldCache.field(loadedID == cardID ? loaded : preloaded, cardID: cardID),
            allowsPrism: !(material == .gold(.swordShieldGold)
                && CardIndex.shared?.card(cardID)?.visualKind?.supertype == .pokemon))
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
    /// Keys whose last segmentation found no foreground. A retry still runs; this only lets
    /// a subject-only foil fall back to the whole illustration instead of vanishing.
    private static var failures: Set<String> = []
    static func mask(key: String) -> CGImage? { cache.object(forKey: key as NSString)?.image }
    static func failed(key: String) -> Bool { failures.contains(key) }
    /// 전경 분리가 아무것도 찾지 못하는 그림이 있다(언노운 I, M 처럼 글자 모양 포켓몬, ex13-2 릴리요).
    /// 그때만 "눈에 띄는 물체" 열지도로 부드러운 윤곽을 만든다. 거친 덩어리지만, 배경만 칠할 포일이
    /// 포켓몬까지 덮거나 포켓몬만 칠할 포일이 그림 칸 전체로 번지는 것보다 실물에 가깝다.
    /// Alpha mask of gold-coloured ink (hue about 30-60 degrees, saturated, not dark).
    nonisolated static func goldInkMask(_ image: CGImage) -> CGImage? {
        let width = min(360, image.width)
        let height = max(1, Int(Double(image.height) * Double(width) / Double(image.width)))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var mask = [UInt8](repeating: 0, count: width * height)
        for p in 0..<(width * height) {
            let r = Double(rgba[p * 4]) / 255, g = Double(rgba[p * 4 + 1]) / 255, b = Double(rgba[p * 4 + 2]) / 255
            let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
            guard maxC > 0.30, delta / max(maxC, 0.001) > 0.28, r >= g, g > b else { continue }
            let hue = (g - b) / max(delta, 0.001) / 6 // red-to-yellow sector, 0...1/6
            if hue > 0.08 && hue <= 1.0 / 6 { mask[p] = 255 }
        }
        guard let provider = CGDataProvider(data: Data(mask) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            .map { CIImage(cgImage: $0).applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.2])
                .cropped(to: CGRect(x: 0, y: 0, width: width, height: height)).applyingFilter("CIMaskToAlpha") }
            .flatMap { CIContext().createCGImage($0, from: CGRect(x: 0, y: 0, width: width, height: height)) }
    }

    nonisolated static func salientObjectMask(handler: VNImageRequestHandler, size: CGSize) -> CGImage? {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              observation.salientObjects?.isEmpty == false else { return nil }
        let heat = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let scaled = heat.transformed(by: CGAffineTransform(scaleX: size.width / heat.extent.width,
                                                            y: size.height / heat.extent.height))
        // 열지도 0.35~0.60 을 부드러운 가장자리로 펴서 0~1 마스크로 만든다.
        let gain: CGFloat = 4, bias: CGFloat = -1.4
        let mask = scaled
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
            ])
            .applyingFilter("CIColorClamp")
            .applyingFilter("CIMaskToAlpha")
        return CIContext().createCGImage(mask, from: CGRect(origin: .zero, size: size))
    }

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
        // BREAK Pokémon are printed in gold over a coloured background, and the
        // foreground model takes almost the whole card as the subject. Use the
        // gold ink itself as the subject there (2026-10-19 render check).
        let goldSubject = CardIndex.shared?.card(cardID)?.rarity == "Rare BREAK"
        let result = await Task.detached(priority: .utility) {
            if goldSubject { return ArtworkMaskCache.goldInkMask(artwork) }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: artwork)
            guard (try? handler.perform([request])) != nil,
                  let observation = request.results?.first, !observation.allInstances.isEmpty,
                  let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances,
                                                                           from: handler) else {
                return ArtworkMaskCache.salientObjectMask(handler: handler, size: CGSize(width: artwork.width,
                                                                                         height: artwork.height))
            }
            let image = CIImage(cvPixelBuffer: buffer).applyingFilter("CIMaskToAlpha")
            return CIContext().createCGImage(image, from: image.extent)
        }.value
        // Failed segmentation is retryable; don't permanently cache a miss.
        if let result {
            cache.setObject(Entry(result, source: source), forKey: cacheKey)
            failures.remove(cacheKey as String)
        } else {
            failures.insert(cacheKey as String)
        }
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
            if coverage == .outsideSubject {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                if let mask = preparedMask {
                    artContext.blendMode = .destinationOut
                    artContext.draw(Image(decorative: mask, scale: 1), in: rect)
                }
                return
            }
            // 분리가 실패하면(그림에서 포켓몬을 찾지 못함) 포켓몬만 칠할 포일이 통째로 사라졌다
            // (예: ex13-2 리버스). 실패한 카드는 예전처럼 그림 칸 전체에 포일을 둔다.
            if coverage == .artSubject, preparedMask == nil,
               maskKey == key || ArtworkMaskCache.failed(key: key) {
                artContext.fill(artwork, with: .color(.white))
                return
            }
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
