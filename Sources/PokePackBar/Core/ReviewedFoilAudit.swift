import Foundation
import SwiftUI

/// Registration/routing checks, deliberately not labelled physical approval.
@MainActor
enum ReviewedFoilAudit {
    static func verify(index: CardIndex) throws {
        let entries = ReviewedFoilProfiles.entries
        try LocalAudit.require(entries.count == 85, "Reviewed cohort lost a decoded/registered printing")
        try LocalAudit.require(ReviewedFoilProfiles.starSheetExclusions.count == 12,
            "30th ordinary ex matte stamps acquired star foil")
        try RegisteredCrackedIce.verify()
        for (key, entry) in entries {
            guard let card = index.card(entry.cardID), let art = CardArtLibrary.entries[entry.cardID] else {
                throw LocalAudit.Failure(description: "Reviewed original missing: \(key)")
            }
            let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                explicitFinish: entry.finish)
            try LocalAudit.require(resolved.spec.isFoil, "Reviewed printing became nonfoil: \(key)")
            try LocalAudit.require(ReviewedFoilProfiles.entry(cardID: card.id, finish: .normal) == nil,
                                   "Reviewed profile leaked onto normal printing")
            try LocalAudit.require(!ReviewedFoilProfiles.accepts(entry, hash: "replacement", width: art.width, height: art.height)
                && !ReviewedFoilProfiles.accepts(entry, hash: art.sha256, width: art.width + 1, height: art.height),
                "Stale scan registration accepted")
            try LocalAudit.require(entry.fans.isEmpty == !entry.layers.contains { $0.material == .radialFans },
                                   "Fans missing from dispatch: \(key)")
            try LocalAudit.require(entry.baseInclude.isEmpty || resolved.spec.treatment != nil,
                                   "Unresolved base region cannot be rendered: \(key)")
            for layer in entry.layers {
                let path = ReviewedFoilProfiles.path(layer.include, size: CGSize(width: 1, height: 1))
                try LocalAudit.require(!path.isEmpty && path.boundingRect.width > 0 && path.boundingRect.height > 0,
                                       "Empty registered layer: \(key)/\(layer.name)")
            }
        }
        func layer(_ id: String, _ name: String) throws -> ReviewedFoilProfiles.Layer {
            guard let value = entries.values.first(where: { $0.cardID == id })?.layers.first(where: { $0.name == name }) else {
                throw LocalAudit.Failure(description: "Missing expected material: \(id)/\(name)")
            }
            return value
        }
        func contains(_ layer: ReviewedFoilProfiles.Layer, _ x: Double, _ y: Double) -> Bool {
            // Query CoreGraphics even-odd fill directly, matching Canvas clip.
            // SwiftUI Path.contains disagrees on compound image-traced paths.
            let size = CGSize(width: 240, height: 336), point = CGPoint(x: x * 240, y: y * 336)
            return ReviewedFoilProfiles.path(layer.include, size: size).cgPath.contains(point, using: .evenOdd)
                && !ReviewedFoilProfiles.path(layer.exclude, size: size).cgPath.contains(point, using: .evenOdd)
        }
        let classic = try layer("cel30c-14", "illustration-confetti")
        for (name, x, y) in [("body",0.50,0.40),("tail",0.80,0.36),("matte rules",0.50,0.75)] {
            try LocalAudit.require(!contains(classic, x, y), "Classic Pikachu \(name) acquired confetti")
        }
        let cleffa = try layer("cel25c-20_A", "illustration-confetti")
        try LocalAudit.require(!contains(cleffa, 0.48, 0.34) && contains(cleffa, 0.21, 0.22),
                               "Cleffa chair was mistaken for its body")
        let mewtwo = try layer("cel25c-54_A", "illustration-confetti")
        try LocalAudit.require(contains(mewtwo, 0.16, 0.25) && !contains(mewtwo, 0.79, 0.23),
                               "Mewtwo energy sphere or face misregistered")
        for id in ["cel25c-15_A1", "cel25c-2_A", "cel25c-4_A"] {
            try LocalAudit.require(entries.values.first { $0.cardID == id }?.layers.contains {
                $0.material == .goldFragments || $0.material == .goldStars
            } == false, "25th yellow paper was replaced with 30th gold foil")
        }
        for id in ["cel25c-113_A", "cel25c-114_A"] {
            try LocalAudit.require(contains(try layer(id, "illustration-confetti"), 0.5, 0.35),
                                   "Full-art subject was universally excluded")
        }
        for number in 23...52 {
            let entry = entries["cel30-\(number)#fullArt"]
            try LocalAudit.require(entry?.baseInclude.isEmpty == true && entry?.fans.isEmpty == false,
                                   "Pikachu returned to unresolved tiny-star fallback: \(number)")
        }
        try LocalAudit.require(entries["cel25c-15_A2#celebrationsClassic"]?.evidenceStatus
            == "additional_front_and_oblique_photos_background_compared",
            "Rocket correction lost its additional photographic evidence")
        let neutral = TiltVector(nx: 0, ny: 0), tilted = TiltVector(nx: 0.65, ny: -0.45)
        try LocalAudit.require(abs(ReviewedFoilLayer.facetResponse(phase: 0, tilt: neutral)
            - ReviewedFoilLayer.facetResponse(phase: 0, tilt: tilted)) > 0.3,
            "Facets do not respond to tilt")
        try verifyFacetDistribution()
        let smallTilt = TiltVector(nx: 0.18, ny: -0.12)
        let confettiResponse = ReviewedFoilLayer.facetResponse(
            phase: 0, tilt: smallTilt, material: .confetti)
        let etchingResponse = ReviewedFoilLayer.facetResponse(
            phase: 0, tilt: smallTilt, material: .microEtching)
        let goldRimResponse = ReviewedFoilLayer.starResponse(
            phase: 0, tilt: smallTilt, goldBorder: true)
        try LocalAudit.require(abs(confettiResponse - etchingResponse) > 0.08
                               && abs(confettiResponse - goldRimResponse) > 0.08,
                               "Confetti, micro-etching and gold rim share one reflection speed")
        for number in 1...30 {
            let id = "cel30c-\(number)"
            let rim = try layer(id, "gold-rim")
            try LocalAudit.require(rim.include == ExpansionFoil.entries[id]?.goldFrame,
                "Classic rim reverted to generic frame: \(id)")
            _ = try layer(id, "illustration-stars")
        }
        print("PASS reviewed foil: 85 explicit printings, no diagonal hue bands, independent facet normals with weak local coherence, distinct confetti/etching/gold speeds, all 30 Classic gold masks, 12 registered shard sets; physical plates NOT certified; wallet untouched")
    }

    /// Rejects the former `x * 0.42 + y * 0.58` colour partition. Hue is
    /// circular, so both sine and cosine components must be uncorrelated with
    /// that axis; checking the numeric hue directly would be invalid at wrap.
    private static func verifyFacetDistribution() throws {
        var generator = PackSeedGenerator(seed: 0xC31E_BA71)
        func next() -> Double { Double(generator.next() >> 11) / Double(1 << 53) }
        var diagonal: [Double] = []
        var hueX: [Double] = []
        var hueY: [Double] = []
        var groups = Set<Int>()
        diagonal.reserveCapacity(12_000)
        hueX.reserveCapacity(12_000)
        hueY.reserveCapacity(12_000)
        for _ in 0..<12_000 {
            let x = next(), y = next(), independentHue = next(), independentNormal = next()
            let hue = ReviewedFacetDistribution.huePhase(
                x: x, y: y, independent: independentHue, seed: 0xC31E_BA71)
            diagonal.append(x * 0.42 + y * 0.58)
            hueX.append(cos(hue * .pi * 2))
            hueY.append(sin(hue * .pi * 2))
            groups.insert(ReviewedFacetDistribution.group(
                x: x, y: y, independentHue: independentHue,
                independentNormal: independentNormal, seed: 0xC31E_BA71))
        }
        let directionalCorrelation = max(abs(correlation(diagonal, hueX)),
                                         abs(correlation(diagonal, hueY)))
        try LocalAudit.require(directionalCorrelation < 0.08,
                               "Reviewed facets still form a diagonal colour band")
        try LocalAudit.require(groups.count == ReviewedFacetDistribution.groupCount,
                               "Reviewed facets lost independent hue/normal phases")
    }

    private static func correlation(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 1 }
        let lhsMean = lhs.reduce(0, +) / Double(lhs.count)
        let rhsMean = rhs.reduce(0, +) / Double(rhs.count)
        var numerator = 0.0, lhsSquared = 0.0, rhsSquared = 0.0
        for (left, right) in zip(lhs, rhs) {
            let l = left - lhsMean, r = right - rhsMean
            numerator += l * r
            lhsSquared += l * l
            rhsSquared += r * r
        }
        let denominator = sqrt(lhsSquared * rhsSquared)
        return denominator > 0 ? numerator / denominator : 1
    }
}
