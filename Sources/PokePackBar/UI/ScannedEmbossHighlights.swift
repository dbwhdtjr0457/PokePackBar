import AppKit
import SwiftUI

/// Image-derived ridge positions, not factory normals. Flat ink never becomes
/// a foil carrier; bright and dark angular responses share the same fixed masks.
@MainActor
struct ScannedEmbossHighlights: View {
    let source: NSImage
    let cardID: String
    let isWhite: Bool
    let isMonochrome: Bool
    let tilt: TiltVector

    var body: some View {
        let masks = ScannedEmbossCache.masks(source: source, cardID: cardID, isWhite: isWhite)
        Canvas { context, size in
            for (group, mask) in masks.enumerated() {
                let response = ScannedEmbossCache.response(group: group, tilt: tilt)
                var ridge = context
                let white: Double = response >= 0 ? 1 : 0.04
                let strength = isMonochrome ? 0.55 : (isWhite ? 0.90 : 0.96)
                ridge.opacity = abs(response) * strength
                var tint = ColorMatrix()
                tint.r1 = Float(white); tint.g2 = Float(white); tint.b3 = Float(white)
                ridge.addFilter(.colorMatrix(tint))
                ridge.draw(Image(decorative: mask, scale: 1), in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

@MainActor
enum ScannedEmbossCache {
    static let groupCount = 12
    private final class Entry {
        let source: NSImage
        let masks: [CGImage]
        init(source: NSImage, masks: [CGImage]) { self.source = source; self.masks = masks }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.totalCostLimit = 48 * 1024 * 1024
        cache.countLimit = 4
        return cache
    }()

    static func response(group: Int, tilt: TiltVector) -> Double {
        let phase = Double(group) / Double(groupCount) * .pi * 2
        return sin(phase + tilt.nx * 4.4 + tilt.ny * 3.2)
    }

    static func ridgeWeight(light: Double, localMean: Double, isWhite: Bool) -> Double {
        func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
        let carrier = isWhite ? clamp((1 - light) * 4.5) : clamp(light * 2.6)
        let excludeInk = isWhite ? clamp(light * 8 - 4.4) : clamp(4.4 - light * 8)
        return carrier * excludeInk * clamp(abs(light - localMean) * 22)
    }

    static func masks(source: NSImage, cardID: String, isWhite: Bool) -> [CGImage] {
        let key = "\(cardID)#\(isWhite)#\(ObjectIdentifier(source))" as NSString
        if let entry = cache.object(forKey: key) { return entry.masks }
        guard let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let width = 480, height = Int(Double(480 * image.height) / Double(image.width))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let success = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { return [] }
        var light = [Double](repeating: 0, count: width * height)
        for p in light.indices {
            light[p] = (Double(rgba[p * 4]) * 0.2126 + Double(rgba[p * 4 + 1]) * 0.7152
                + Double(rgba[p * 4 + 2]) * 0.0722) / 255
        }
        var alpha = Array(repeating: [UInt8](repeating: 0, count: light.count), count: groupCount)
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let p = y * width + x
                let mean = (light[p - 2] + light[p + 2] + light[p - 2 * width] + light[p + 2 * width]) / 4
                let weight = ridgeWeight(light: light[p], localMean: mean, isWhite: isWhite)
                guard weight > 0.015 else { continue }
                let dx = light[p + 1] - light[p - 1], dy = light[p + width] - light[p - width]
                let local = FoilAreaLighting.neighbourhoodPhase(x: Double(x) / Double(width),
                    y: Double(y) / Double(height), seed: 0x425752, columns: 22)
                let phase = atan2(dy, dx) + local * 0.35 + .pi * 4
                let group = (phase / (.pi * 2) * Double(groupCount)).truncatingRemainder(dividingBy: Double(groupCount))
                let first = Int(group), fraction = group - floor(group)
                alpha[first][p] = UInt8(min(255, weight * (1 - fraction) * 255))
                alpha[(first + 1) % groupCount][p] = UInt8(min(255, weight * fraction * 255))
            }
        }
        var masks: [CGImage] = []
        for group in 0..<groupCount {
            for p in light.indices {
                let a = alpha[group][p]
                rgba[p * 4] = a; rgba[p * 4 + 1] = a; rgba[p * 4 + 2] = a; rgba[p * 4 + 3] = a
            }
            guard let provider = CGDataProvider(data: Data(rgba) as CFData),
                  let mask = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return [] }
            masks.append(mask)
        }
        cache.setObject(Entry(source: source, masks: masks), forKey: key, cost: rgba.count * groupCount)
        return masks
    }
}
