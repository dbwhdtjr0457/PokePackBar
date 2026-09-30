import AppKit
import SwiftUI

/// Diagnostic only. Scores compare the production render with its unlit scan;
/// they are not physical-fidelity certification or a replacement for inspection.
@MainActor
enum FoilArtworkAudit {
    static let poseNames = ["rest", "near-left", "near-right", "near-up", "near-down",
                            "left", "right", "up", "down", "diagonal"]
    struct Pose: Codable {
        let name: String
        let artDelta: Double
        let brightVeilFraction: Double
        let darkVeilFraction: Double
        let edgeRetention: Double
        let edgeCorrelation: Double
        let weakenedEdgeFraction: Double
        let addedClippingFraction: Double
        let faintEdgeRetention: Double
        let faintEdgeCorrelation: Double
    }
    struct Result: Codable {
        let artPixels: Int
        let edgeSamples: Int
        let faintEdgeSamples: Int
        let poses: [Pose]
        let worstPose: String
        let flags: [String]
    }
    struct Strength: Codable {
        let factor: Double
        let artwork: Result
        let smallFoil: Double
        let largeFoil: Double
        let fineFoil: Double
    }

    static func supplements(index: CardIndex) -> [String: (CardEntry, [CardFinish?])] {
        var finishes: [String: Set<CardFinish>] = [:]
        for set in index.sets {
            let era = index.era(set.id)
            let variants: [PackVariant] = ["rsv10pt5", "zsv10pt5"].contains(set.id)
                ? [.standard, .blackBoltWhiteFlareGod] : [.standard]
            for variant in variants {
                let supplement = PackSupplement.contents(setID: set.id, era: era, variant: variant)
                guard supplement.energyCount > 0 else { continue }
                // Cycle the production style/type selector through every type,
                // rather than inventing another material/style eligibility map.
                let allTypes = PackSupplement(energyCount: 9, holoEnergy: supplement.holoEnergy, codeCount: 0)
                for card in SupplementalEnergyCard.cards(setID: set.id, era: era,
                                                         supplement: allTypes, expansionCards: []) {
                    finishes[card.id, default: []].insert(card.finish)
                    if let reverse = PackRecipe.reverseSlotEnergyFinish[set.id] {
                        finishes[card.id, default: []].insert(reverse)
                    }
                }
            }
        }
        return finishes.reduce(into: [:]) { result, entry in
            let (id, values) = entry
            result[id] = (CardEntry(id: id, name: SupplementalEnergyCard.displayName(cardID: id, language: .en) ?? id,
                tier: .energy, setID: "supplement"),
                values.sorted { $0.rawValue < $1.rawValue }.map { Optional($0) })
        }
    }

    static func reference(card: CardEntry, source: NSImage) throws -> [UInt8] {
        try CatalogueFoilAudit.pixels(ZStack {
            Color.black
            CardImageView(cardID: card.id, hires: true, width: 240, preloaded: source)
        })
    }

    static func artRegion(cardID: String, source: NSImage) throws -> [Bool] {
        let mask = try CatalogueFoilAudit.pixels(ZStack {
          Color.black
          CardImageView(cardID: cardID, hires: true, width: 240, preloaded: source,
            imageOverlay: { _ in AnyView(Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            let art = FoilGeometry.artRect(cardID: cardID, in: size)
            let interior = CGRect(x: size.width * 0.06, y: size.height * 0.06,
                                  width: size.width * 0.88, height: size.height * 0.88)
            context.fill(Path(art.intersection(interior)), with: .color(.white))
            }) })
        })
        return (0..<(240 * 335)).map { mask[$0 * 4] > 127 }
    }

    /// Smooth away sub-pixel grain before measuring source-aligned edges. Raw
    /// sharpness alone would incorrectly reward added noise for hiding artwork.
    static func luminance(_ pixels: [UInt8]) -> [Double] {
        let width = 240, height = 335
        let raw: [Double] = (0..<(width * height)).map { p -> Double in
            let red = 0.2126 * Double(pixels[p * 4])
            let green = 0.7152 * Double(pixels[p * 4 + 1])
            let blue = 0.0722 * Double(pixels[p * 4 + 2])
            return red + green + blue
        }
        var smooth = raw
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let p = y * width + x
                let adjacent = raw[p-1] + raw[p+1] + raw[p-width] + raw[p+width]
                let diagonal = raw[p-width-1] + raw[p-width+1] + raw[p+width-1] + raw[p+width+1]
                smooth[p] = (raw[p] * 4 + adjacent * 2 + diagonal) / 16
            }
        }
        return smooth
    }

    static func measure(reference: [UInt8], frames: [[UInt8]], region: [Bool]) -> Result {
        let base = luminance(reference)
        let active = region.indices.filter { region[$0] }
        var edges: [(Int, Int, Double)] = []
        var faintEdges: [(Int, Int, Double)] = []
        for p in active where p % 240 > 2 && p % 240 < 237 && p > 480 && p < 240 * 333 {
            for offset in [2, 480] where region[p - offset] && region[p + offset] {
                let d = base[p + offset] - base[p - offset]
                if abs(d) >= 12 { edges.append((p - offset, p + offset, d)) }
                else if abs(d) >= 3 { faintEdges.append((p - offset, p + offset, d)) }
            }
        }
        let sourcePower = edges.reduce(0.0) { $0 + $1.2 * $1.2 }
        let faintSourcePower = faintEdges.reduce(0.0) { $0 + $1.2 * $1.2 }
        var poses: [Pose] = []
        for (i, frame) in frames.enumerated() {
            let actual = luminance(frame)
            var delta = 0.0, bright = 0.0, dark = 0.0, clipped = 0.0
            for p in active {
                let d = actual[p] - base[p]
                delta += abs(d)
                if d > 35 { bright += 1 }
                if d < -35 { dark += 1 }
                if actual[p] > 245 && base[p] < 225 { clipped += 1 }
            }
            var cross = 0.0, power = 0.0, weak = 0.0
            for (a, b, original) in edges {
                let rendered = actual[b] - actual[a]
                cross += original * rendered
                power += rendered * rendered
                if rendered * original <= 0 || abs(rendered) < abs(original) * 0.65 { weak += 1 }
            }
            let count = Double(max(1, active.count))
            var faintCross = 0.0, faintPower = 0.0
            for (a, b, original) in faintEdges {
                let rendered = actual[b] - actual[a]
                faintCross += original * rendered
                faintPower += rendered * rendered
            }
            poses.append(Pose(name: poseNames[i], artDelta: delta / count,
                brightVeilFraction: bright / count, darkVeilFraction: dark / count,
                edgeRetention: sourcePower > 0 ? cross / sourcePower : 1,
                edgeCorrelation: sourcePower * power > 0 ? cross / sqrt(sourcePower * power) : 1,
                weakenedEdgeFraction: weak / Double(max(1, edges.count)), addedClippingFraction: clipped / count,
                faintEdgeRetention: faintSourcePower > 0 ? faintCross / faintSourcePower : 1,
                faintEdgeCorrelation: faintSourcePower * faintPower > 0 ? faintCross / sqrt(faintSourcePower * faintPower) : 1))
        }
        let worst = poses.max { risk($0) < risk($1) }!
        var flags: [String] = []
        if poses.contains(where: { $0.brightVeilFraction > 0.15 }) { flags.append("bright-veil") }
        if poses.contains(where: { $0.darkVeilFraction > 0.15 }) { flags.append("dark-veil") }
        if edges.count >= 100 && poses.contains(where: { $0.edgeRetention < 0.80 }) { flags.append("source-contrast-loss") }
        if edges.count >= 100 && poses.contains(where: { $0.weakenedEdgeFraction > 0.25 }) { flags.append("local-edge-loss") }
        if poses.contains(where: { $0.addedClippingFraction > 0.02 }) { flags.append("added-clipping") }
        if edges.count < 100 { flags.append("low-source-edge-evidence") }
        if faintEdges.count >= 100 && poses.contains(where: { $0.faintEdgeCorrelation < 0.80 }) { flags.append("faint-detail-interference") }
        return Result(artPixels: active.count, edgeSamples: edges.count, faintEdgeSamples: faintEdges.count, poses: poses,
                      worstPose: worst.name, flags: flags)
    }

    static func risk(_ pose: Pose) -> Double {
        max(0, 1 - pose.edgeRetention) + pose.weakenedEdgeFraction
            + pose.brightVeilFraction + pose.darkVeilFraction + pose.addedClippingFraction
    }

    /// Native compositing experiment, not a production change: retain the
    /// source and attenuate the complete rendered coating over it. This does
    /// NOT selectively preserve glint peaks, so it only establishes a baseline.
    static func capture(card: CardEntry, source: NSImage, finish: CardFinish, spec: FoilSpec,
                        directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let selected = [0, 2, 6]
        let view = VStack(spacing: 12) {
            ForEach([1.0, 0.70, 0.55, 0.40], id: \.self) { strength in
                HStack(spacing: 12) {
                    VStack {
                        Text("\(card.id) / scan").foregroundStyle(.white)
                        CardImageView(cardID: card.id, hires: true, width: 240, preloaded: source)
                    }
                    ForEach(selected, id: \.self) { i in
                        VStack {
                            Text("\(poseNames[i]) / \(Int(strength * 100))%").foregroundStyle(.white)
                            ZStack {
                                CardImageView(cardID: card.id, hires: true, width: 240, preloaded: source)
                                HoloCardBody(cardID: card.id, tier: card.tier, finish: finish, spec: spec,
                                    width: 240, height: 335, dimmed: false, preloaded: source,
                                    visualKind: card.visualKind, tilt: CatalogueFoilAudit.poses[i], flatCard: true)
                                    .compositingGroup()
                                    .opacity(strength)
                            }
                            .frame(width: 240, height: 335).clipped()
                        }
                    }
                }
            }
        }.font(.system(size: 13)).padding(14).background(Color(white: 0.06))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let cg = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { throw LocalAudit.Failure(description: "Cannot render artwork comparison") }
        try data.write(to: directory.appendingPathComponent("\(card.id)-\(finish.rawValue).png"), options: .withoutOverwriting)
        let reference = try reference(card: card, source: source)
        let region = try artRegion(cardID: card.id, source: source)
        let mask = try CatalogueFoilAudit.pixels(ZStack {
            Color.black
            CatalogueFoilAudit.auditMask(cardID: card.id, finish: finish, spec: spec, source: source)
        })
        let foilRegion = (0..<(240 * 335)).map { p in
            p % 240 > 5 && p % 240 < 235 && p > 1200 && p < 240 * 330 && mask[p * 4] > 127
        }
        var studies: [Strength] = []
        for strength in [1.0, 0.85, 0.70, 0.55, 0.40] {
            var frames: [[UInt8]] = []
            for tilt in CatalogueFoilAudit.poses {
                frames.append(try CatalogueFoilAudit.pixels(ZStack {
                    Color.black
                    CardImageView(cardID: card.id, hires: true, width: 240, preloaded: source)
                    HoloCardBody(cardID: card.id, tier: card.tier, finish: finish, spec: spec,
                        width: 240, height: 335, dimmed: false, preloaded: source,
                        visualKind: card.visualKind, tilt: tilt, flatCard: true)
                        .compositingGroup().opacity(strength)
                }))
            }
            let signalRegion = foilRegion.contains(true) ? foilRegion : region
            let signal = CatalogueFoilAudit.measure(frames: frames, region: signalRegion)
            studies.append(Strength(factor: strength, artwork: measure(reference: reference, frames: frames, region: region),
                                    smallFoil: signal.small, largeFoil: signal.large, fineFoil: signal.detail))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(studies).write(to: directory.appendingPathComponent("\(card.id)-\(finish.rawValue)-strengths.json"),
                                         options: .withoutOverwriting)
    }

    static func verify() throws {
        var source = [UInt8](repeating: 255, count: 240 * 335 * 4)
        for p in 0..<(240 * 335) {
            let value: UInt8 = ((p % 240) / 16 + (p / 240) / 16).isMultiple(of: 2) ? 45 : 180
            for c in 0..<3 { source[p * 4 + c] = value }
        }
        let region = (0..<(240 * 335)).map { p in p % 240 > 5 && p % 240 < 235 && p > 1200 && p < 240 * 330 }
        let control = measure(reference: source, frames: Array(repeating: source, count: 10), region: region)
        try LocalAudit.require(control.flags.isEmpty && abs(control.poses[0].edgeRetention - 1) < 0.0001,
                               "Artwork control failed")
        var washed = source
        for p in 0..<(240 * 335) { for c in 0..<3 { washed[p * 4 + c] = UInt8(Double(source[p * 4 + c]) * 0.5 + 127) } }
        let mutation = measure(reference: source, frames: Array(repeating: washed, count: 10), region: region)
        try LocalAudit.require(mutation.flags.contains("bright-veil") && mutation.flags.contains("source-contrast-loss"),
                               "Artwork diagnostic accepted a white veil")
        print("PASS artwork diagnostics: identity control and 50% white-veil rejection")
    }
}
