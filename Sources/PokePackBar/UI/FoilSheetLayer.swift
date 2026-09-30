import AppKit
import SwiftUI

/// Untextured diffraction sheets are not etched full arts. In particular,
/// Cosmos scans already contain their registered orbs and scattered flecks.
enum FoilSheetMaterial: String {
    case cosmos
    case celebration
    case legend
    case goldStar
    case refractorGoldStar
    case dimensionalBalls
    case doubleRare
    case deltaSpecies
    case radiantCollection

    init?(pattern: FoilPattern, cardID: String) {
        switch pattern {
        case .satin where cardID.hasPrefix("g1-RC"): self = .radiantCollection
        case .cosmos, .cosmosStamp: self = .cosmos
        case .celebrationSheen: self = .celebration
        case .legend: self = .legend
        case .starSheen where cardID.hasPrefix("ex"): self = .goldStar
        case .refractor where FoilMaterialCatalog.isRefractorGoldStar(cardID): self = .refractorGoldStar
        case .refractor where FoilSubjectMasks.requiresRegisteredMask(cardID: cardID)
            && !FoilReliefMaterial.neoShiningCardIDs.contains(cardID): self = .deltaSpecies
        case .pokeBall3D: self = .dimensionalBalls
        case .doubleRareSheen: self = .doubleRare
        default: return nil
        }
    }
}

@MainActor
struct FoilSheetLayer: View {
    let material: FoilSheetMaterial
    let source: NSImage
    let cardID: String
    let tilt: TiltVector

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = UnitPoint(x: 0.46 - tilt.nx * (material == .deltaSpecies || material == .radiantCollection ? 0.50 : 0.34),
                                   y: 0.35 - tilt.ny * 0.26)
            if material == .dimensionalBalls {
                DimensionalBallSheet(tilt: tilt)
            } else if material == .doubleRare {
                // SV-era ordinary ex: a smooth substrate with fixed mixed
                // starbursts. This is not the five-point Classic gold sheet,
                // a Tera engraving, or a moving sparkle particle system.
                DoubleRareStarSheet(tilt: tilt)
                    .mask(Canvas { context, size in
                        var region = Path(CGRect(origin: .zero, size: size))
                        if let stamp = ReviewedFoilProfiles.starSheetExclusions[cardID] {
                            region.addPath(ReviewedFoilProfiles.path(stamp.contours, size: size))
                        }
                        context.fill(region, with: .color(.white), style: FillStyle(eoFill: true))
                    })
            } else if material == .cosmos || material == .goldStar {
                if let masks = FoilScanGlintCache.masks(source: source, cardID: cardID) {
                    // Re-light source-visible flecks, not random circles laid
                    // on top of the Pokémon. The mask never moves with tilt.
                    ZStack {
                        // Fine foil substrate remains visible between the scan's
                        // registered flecks. This adds no fabricated large orbs.
                        FoilReliefLayer(material: .engraved(.cosmos, .none),
                            seed: 0x434F_534D_4F53, tilt: tilt,
                            coatingScale: FoilArtworkBalance.entries[cardID]?.coatingGain ?? 1)
                            .opacity(material == .goldStar ? 0.62 : 0.78)
                            .mask {
                                ArtworkFoilMask(cardID: cardID, preloaded: source, coverage: .artBackground,
                                    art: FoilGeometry.artRect(cardID: cardID, in: CGSize(width: 1, height: 1)),
                                    requirePreparedMask: true)
                            }
                        ForEach(masks.indices, id: \.self) { group in
                            let energy = FoilScanGlintCache.reflectionEnergy(group: group, x: tilt.nx, y: tilt.ny)
                            let color = (hue + Double(group) * 0.17).truncatingRemainder(dividingBy: 1)
                            ZStack {
                                // An unlit fleck must not turn into a black
                                // hole over a source-visible star or art edge.
                                Color.black.opacity((1 - energy)
                                    * (FoilArtworkBalance.entries[cardID]?.dormantFleckOpacity ?? 0.88))
                                RadialGradient(colors: [
                                    Color(hue: color, saturation: 0.15, brightness: 1),
                                    Color(hue: color, saturation: 0.78, brightness: 1).opacity(0.82),
                                    Color(hue: color, saturation: 0.72, brightness: 1).opacity(0.26),
                                ], center: center, startRadius: 0, endRadius: size.width * 0.76)
                                .opacity(min(1, energy * 1.5))
                            }
                            .mask { Image(decorative: masks[group], scale: 1).resizable() }
                        }
                    }
                }
            } else {
                // A smooth, unetched sheet: broad spectral lobes, no drawn
                // stars, grooves or periodic rainbow stripes. Outer geometry
                // still clips this to the printing's registered foil region.
                ZStack {
                    RadialGradient(colors: [Color(hue: hue, saturation: 0.85, brightness: 0.42)
                        .opacity(material == .deltaSpecies ? 0.42 : 0.23), .clear],
                        center: UnitPoint(x: 1 - center.x, y: 1 - center.y),
                        startRadius: 0, endRadius: size.width * 0.58)
                    RadialGradient(stops: [
                        .init(color: .white.opacity(whitePeak), location: 0),
                        .init(color: Color(hue: hue, saturation: 0.72, brightness: 1).opacity(colorPeak), location: 0.28),
                        .init(color: Color(hue: (hue + 0.23).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 1).opacity(0.23), location: 0.57),
                        .init(color: .clear, location: 1),
                    ], center: center, startRadius: 0, endRadius: size.width * 0.65)
                    .blendMode(.screen)
                }
                .mask { Image(decorative: FoilScanGlintCache.sheetGrain, scale: 1).resizable() }
            }
        }
    }

    private var hue: Double {
        let travel = material == .refractorGoldStar || material == .deltaSpecies || material == .radiantCollection ? 0.50 : 0.32
        let value = 0.54 + tilt.nx * travel + tilt.ny * 0.24
        return value - floor(value)
    }

    private var whitePeak: Double {
        switch material {
        case .radiantCollection: 0.24
        case .legend: 0.54
        case .doubleRare: 0.32
        case .deltaSpecies: 0.64
        default: 0.30
        }
    }

    private var colorPeak: Double {
        switch material {
        case .radiantCollection: 0.62
        case .celebration: 0.36
        case .doubleRare: 0.62
        case .deltaSpecies: 0.76
        default: 0.48
        }
    }
}

/// A conservative scan-feature mask, not a recovered printing plate. Reject
/// continuous ink edges and flat fills; retain small bright local components.
/// The source object is retained so address reuse cannot revive a stale mask.
@MainActor
enum FoilScanGlintCache {
    static let sheetGrain: CGImage = {
        let side = 512
        var state: UInt64 = 0x4353_4845_454E
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for p in 0..<(side * side) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let alpha = UInt8(80 + (state >> 32) % 176)
            for channel in 0..<4 { pixels[p * 4 + channel] = alpha }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()
    private final class Entry {
        let source: NSImage
        let masks: [CGImage]
        init(source: NSImage, masks: [CGImage]) { self.source = source; self.masks = masks }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 16; cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    static func masks(source: NSImage, cardID: String) -> [CGImage]? {
        let key = "\(cardID)#\(ObjectIdentifier(source))" as NSString
        if let entry = cache.object(forKey: key) { return entry.masks }
        guard let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = 480
        let height = Int(Double(width) * Double(image.height) / Double(image.width))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let success = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { return nil }
        var light = [Double](repeating: 0, count: width * height)
        for p in light.indices {
            // Colored foil can be bright in only one channel.
            light[p] = Double(max(rgba[p * 4], rgba[p * 4 + 1], rgba[p * 4 + 2])) / 255
        }
        var masks: [CGImage] = []
        for group in 0..<3 {
            let alpha = featureAlpha(light: light, width: width, height: height, group: group)
            for p in alpha.indices {
                rgba[p * 4] = alpha[p]; rgba[p * 4 + 1] = alpha[p]
                rgba[p * 4 + 2] = alpha[p]; rgba[p * 4 + 3] = alpha[p]
            }
            guard let provider = CGDataProvider(data: Data(rgba) as CFData),
                  let mask = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
            masks.append(mask)
        }
        cache.setObject(Entry(source: source, masks: masks), forKey: key, cost: width * height * 4 * masks.count)
        return masks
    }

    static func reflectionEnergy(group: Int, x: Double, y: Double) -> Double {
        let phase = x * 3.1 + y * 2.2 + Double(group) * (2 * .pi / 3)
        return pow(max(0, cos(phase)), 2)
    }

    static func featureAlpha(light: [Double], width: Int, height: Int, group: Int? = nil) -> [UInt8] {
        guard width > 8, height > 8, light.count == width * height else { return [] }
        var candidates = [UInt8](repeating: 0, count: light.count)
        for y in 4..<(height - 4) {
            for x in 4..<(width - 4) {
                let p = y * width + x
                let neighbors = [-4, 4, -4 * width, 4 * width,
                    -3 * width - 3, -3 * width + 3, 3 * width - 3, 3 * width + 3]
                let below = neighbors.filter { light[p] - light[p + $0] > 0.10 }.count
                let mean = neighbors.reduce(0.0) { $0 + light[p + $1] } / Double(neighbors.count)
                let contrast = light[p] - mean
                if below >= 5 && light[p] > 0.40 && contrast > 0.10 {
                    candidates[p] = UInt8(min(255, 80 + contrast * 650))
                }
            }
        }
        var visited = [Bool](repeating: false, count: light.count)
        var result = [UInt8](repeating: 0, count: light.count)
        for start in candidates.indices where candidates[start] > 0 && !visited[start] {
            var component = [start]
            visited[start] = true
            var cursor = 0
            var minX = start % width, maxX = minX, minY = start / width, maxY = minY
            while cursor < component.count {
                let p = component[cursor]; cursor += 1
                minX = min(minX, p % width); maxX = max(maxX, p % width)
                minY = min(minY, p / width); maxY = max(maxY, p / width)
                for offset in [-1, 1, -width, width] {
                    let n = p + offset
                    guard n >= 0, n < candidates.count, !visited[n], candidates[n] > 0 else { continue }
                    visited[n] = true; component.append(n)
                }
            }
            guard component.count <= 96, maxX - minX < 18, maxY - minY < 18 else { continue }
            if let group, ((minX * 73856093) ^ (minY * 19349663)) % 3 != group { continue }
            for p in component { result[p] = candidates[p] }
        }
        return result
    }
}
