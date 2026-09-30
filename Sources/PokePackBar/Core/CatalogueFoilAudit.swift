import AppKit
import SwiftUI

/// Every eligible printing, using the production view and its real coverage.
/// Streaming numeric results avoid retaining thousands of PNGs or loading a save.
/// Candidates require visual review; low scores are not proof of a wrong mask.
@MainActor
enum CatalogueFoilAudit {
    static let width = 240
    static let height = 335
    // Sparse stamped symbols occupy a small fraction of their legal foil area.
    // Keep the whole-area score; report a separate fixed-motif score rather
    // than enlarging the artwork or lowering the visibility threshold.
    static let sparsePatterns: Set<FoilPattern> = [.typeSymbols, .sunMoonSymbols,
        .swordShieldTiles, .scarletVioletTiles, .splitTypeSymbols, .energySymbols,
        .energyTypeStamp, .energyPokeBallStamp, .energySetStamp, .pokeBallStars,
        .pokeBallStamp, .rocketStamp, .pinwheel, .pokeBall, .masterBall]
    static let poses: [TiltVector] = [.zero,
        .init(nx: -0.28, ny: 0), .init(nx: 0.28, ny: 0),
        .init(nx: 0, ny: -0.28), .init(nx: 0, ny: 0.28),
        .init(nx: -0.88, ny: 0.02), .init(nx: 0.88, ny: -0.02),
        .init(nx: 0.02, ny: -0.88), .init(nx: -0.02, ny: 0.88), .init(nx: 0.68, ny: -0.68)]

    struct Row: Codable {
        let key: String
        let pattern: String
        let material: String
        let coverage: String
        let status: String
        let regionPixels: Int
        let small: Double
        let large: Double
        let fractionAbove8: Double
        let detail: Double
        let sourceWidth: Int
        let sourceHeight: Int
        let motifPixels: Int?
        let motifSmall: Double?
        let motifLarge: Double?
        let error: String?
        var artwork: FoilArtworkAudit.Result? = nil
    }

    static func pixels<V: View>(_ view: V) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view.frame(width: CGFloat(width), height: CGFloat(height)))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw LocalAudit.Failure(description: "No rendered image") }
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let valid = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard valid else { throw LocalAudit.Failure(description: "Cannot read pixels") }
        return data
    }

    static func run(arguments: [String], at: Int) async throws {
        guard arguments.indices.contains(at + 1), let index = CardIndex.shared else {
            throw LocalAudit.Failure(description: "Expected output JSONL path and bundled catalogue")
        }
        func option(_ flag: String, default value: Int) -> Int {
            guard let i = arguments.firstIndex(of: flag), arguments.indices.contains(i + 1) else { return value }
            return Int(arguments[i + 1]) ?? value
        }
        let shard = option("--shard", default: 0), shards = option("--shards", default: 1)
        let limit = option("--limit", default: Int.max)
        let artworkAudit = arguments.contains("--art-balance")
        if artworkAudit { try FoilArtworkAudit.verify() }
        var selectedKeys: Set<String>?
        if let i = arguments.firstIndex(of: "--keys-file"), arguments.indices.contains(i + 1) {
            selectedKeys = Set(try JSONDecoder().decode([String].self,
                from: Data(contentsOf: URL(fileURLWithPath: arguments[i + 1]))))
        }
        guard shards > 0, (0..<shards).contains(shard), limit > 0 else {
            throw LocalAudit.Failure(description: "Invalid shard or limit")
        }
        let output = URL(fileURLWithPath: arguments[at + 1])
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw LocalAudit.Failure(description: "Refusing to overwrite existing audit")
        }
        try Data().write(to: output, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        var seen = Set<String>(), families = Set<String>(), ordinal = 0, completed = 0
        let encoder = JSONEncoder()
        let supplements = arguments.contains("--supplemental") ? FoilArtworkAudit.supplements(index: index) : [:]
        let cards = arguments.contains("--supplemental") ? supplements.values.map { $0.0 } : index.cards
        for card in cards.sorted(by: { $0.id < $1.id }) {
            for explicit in supplements[card.id]?.1 ?? FoilAuditPrintings.finishes(for: card, index: index) {
                let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                    originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind, explicitFinish: explicit)
                let key = "\(card.id)#\(resolved.finish.rawValue)"
                guard (resolved.spec.isFoil || artworkAudit), seen.insert(key).inserted else { continue }
                defer { ordinal += 1 }
                guard ordinal % shards == shard, completed < limit else { continue }
                if let selectedKeys, !selectedKeys.contains(key) { continue }
                let spec = resolved.spec
                let material = ReviewedFoilProfiles.entry(cardID: card.id, finish: resolved.finish)
                    .map { "reviewed-" + $0.layers.map(\.material.rawValue).joined(separator: "+") }
                    ?? FoilSheetMaterial(pattern: spec.pattern, cardID: card.id).map { "sheet-\($0.rawValue)" }
                    ?? FoilOpticsAudit.material(card.id, spec)?.cacheKey ?? spec.pattern.rawValue
                if arguments.contains("--families") {
                    let family = "\(material)/\(spec.coverage)/\(spec.texture)/\(spec.border)/\(spec.intensity)/\(spec.treatment?.rawValue ?? "none")"
                    guard families.insert(family).inserted else { continue }
                }
                let row: Row
                do {
                    guard let source = await CardImageLoader.image(cardID: card.id, hires: true) else {
                        throw LocalAudit.Failure(description: "Missing source image")
                    }
                    let art = FoilGeometry.artRect(cardID: card.id, in: CGSize(width: 1, height: 1))
                    if [.artBackground, .artSubject, .artSubjectAndBorder].contains(spec.coverage)
                        || [.cosmos, .goldStar].contains(FoilSheetMaterial(pattern: spec.pattern, cardID: card.id)) {
                        _ = await ArtworkMaskCache.prepare(cardID: card.id, source: source, art: art)
                    }
                    row = try autoreleasepool {
                        let mask = try pixels(ZStack {
                            Color.black
                            if spec.isFoil {
                                auditMask(cardID: card.id, finish: resolved.finish, spec: spec, source: source)
                            } else { Color.white }
                        })
                        var region = [Bool](repeating: false, count: width * height)
                        for y in 5..<(height - 5) {
                            for x in 5..<(width - 5) { region[y * width + x] = mask[(y * width + x) * 4] > 127 }
                        }
                        let count = region.filter { $0 }.count
                        guard count > 20 else { throw LocalAudit.Failure(description: "Empty/tiny foil coverage") }
                        var frames: [[UInt8]] = []
                        for tilt in poses {
                            frames.append(try pixels(ZStack {
                                Color.black
                                HoloCardBody(cardID: card.id, tier: card.tier, finish: resolved.finish,
                                    spec: spec, width: CGFloat(width), height: CGFloat(height), dimmed: false,
                                    preloaded: source, visualKind: card.visualKind, tilt: tilt, flatCard: true)
                            }))
                        }
                        let metrics = measure(frames: frames, region: region)
                        let small = metrics.small, large = metrics.large
                        let weak = small < 2.5 || large < 5 || metrics.fraction < 0.10
                        var motifCount: Int?, motifSmall: Double?, motifLarge: Double?
                        var sparsePass = false
                        if weak, spec.treatment == nil, sparsePatterns.contains(spec.pattern) {
                            let motif = try pixels(ZStack {
                                Color.black
                                Color.white.mask {
                                    FinishPatternCanvas(pattern: spec.pattern, seed: HoloCardBody.seed(for: key),
                                        cardID: card.id, visualKind: card.visualKind, alphaGain: 10)
                                }
                            })
                            let active = region.indices.map { region[$0] && motif[$0 * 4] > 32 }
                            let count = active.filter { $0 }.count
                            motifCount = count
                            if count > 100 {
                                let local = measure(frames: frames, region: active)
                                motifSmall = local.small; motifLarge = local.large
                                sparsePass = local.small >= 2.5 && local.large >= 5 && local.fraction >= 0.10
                            }
                        }
                        let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
                        var result = Row(key: key, pattern: spec.pattern.rawValue, material: material,
                            coverage: spec.coverage.rawValue, status: !spec.isFoil ? "nonfoil-control" : weak ? (sparsePass ? "sparse-signal-pass" : "review") : "signal-pass",
                            regionPixels: count, small: small, large: large, fractionAbove8: metrics.fraction,
                            detail: metrics.detail, sourceWidth: cg?.width ?? 0, sourceHeight: cg?.height ?? 0,
                            motifPixels: motifCount, motifSmall: motifSmall, motifLarge: motifLarge,
                            error: nil)
                        if artworkAudit {
                            result.artwork = FoilArtworkAudit.measure(
                                reference: try FoilArtworkAudit.reference(card: card, source: source),
                                frames: frames, region: try FoilArtworkAudit.artRegion(cardID: card.id, source: source))
                            if let i = arguments.firstIndex(of: "--contact-dir"), arguments.indices.contains(i + 1) {
                                try FoilArtworkAudit.capture(card: card, source: source, finish: resolved.finish,
                                    spec: spec, directory: URL(fileURLWithPath: arguments[i + 1]))
                            }
                        }
                        return result
                    }
                } catch {
                    row = Row(key: key, pattern: spec.pattern.rawValue, material: material,
                        coverage: spec.coverage.rawValue, status: "error", regionPixels: 0,
                        small: 0, large: 0, fractionAbove8: 0, detail: 0,
                        sourceWidth: 0, sourceHeight: 0, motifPixels: nil, motifSmall: nil, motifLarge: nil,
                        error: String(describing: error))
                }
                try handle.write(contentsOf: encoder.encode(row) + Data([10]))
                completed += 1
                if completed % 25 == 0 { print("shard \(shard): \(completed) printings; latest \(key)"); fflush(stdout) }
                await Task.yield()
            }
        }
        print("DONE shard \(shard): rendered \(completed); eligible \(ordinal); catalogue \(index.cards.count)")
    }

    static func measure(frames: [[UInt8]], region: [Bool])
        -> (small: Double, large: Double, fraction: Double, detail: Double) {
        var small = 0.0, large = 0.0, above = 0.0, detail = 0.0, count = 0.0
        let base = frames[0]
        for p in region.indices where region[p] {
            var smallPeak = 0.0, largePeak = 0.0, detailPeak = 0.0
            for f in 1..<frames.count {
                let frame = frames[f]
                var delta = 0.0, fine = 0.0
                for c in 0..<3 {
                    let i = p * 4 + c
                    let value = Double(Int(frame[i]) - Int(base[i]))
                    delta += abs(value) / 3
                    if f >= 5 {
                        var mean = 0.0
                        for dy in -1...1 {
                            for dx in -1...1 {
                                let j = (p + dy * width + dx) * 4 + c
                                mean += Double(Int(frame[j]) - Int(base[j])) / 9
                            }
                        }
                        fine += abs(value - mean) / 3
                    }
                }
                if f < 5 { smallPeak = max(smallPeak, delta) } else { largePeak = max(largePeak, delta) }
                detailPeak = max(detailPeak, fine)
            }
            small += smallPeak; large += largePeak; detail += detailPeak
            if largePeak > 8 { above += 1 }
            count += 1
        }
        return (small / count, large / count, above / count, detail / count)
    }

    @ViewBuilder
    static func auditMask(cardID: String, finish: CardFinish, spec: FoilSpec, source: NSImage) -> some View {
        if let profile = ReviewedFoilProfiles.entry(cardID: cardID, finish: finish) {
            Canvas { context, size in
                for (include, exclude) in [(profile.baseInclude, profile.baseExclude)]
                    + profile.layers.map({ ($0.include, $0.exclude) }) where !include.isEmpty {
                    var layer = context
                    layer.clip(to: ReviewedFoilProfiles.path(include, size: size), style: FillStyle(eoFill: true))
                    var outside = Path(CGRect(origin: .zero, size: size))
                    outside.addPath(ReviewedFoilProfiles.path(exclude, size: size))
                    layer.clip(to: outside, style: FillStyle(eoFill: true))
                    layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                }
            }
        } else if spec.pattern == .crackedIce, let entry = RegisteredCrackedIce.entries[cardID] {
            Canvas { context, size in
                for facet in entry.facets {
                    context.fill(ReviewedFoilProfiles.path(facet.regions, size: size),
                                 with: .color(.white), style: FillStyle(eoFill: true))
                }
            }
        } else {
            FoilCoverageMask(coverage: spec.coverage, cardID: cardID, preloaded: source)
        }
    }
}
