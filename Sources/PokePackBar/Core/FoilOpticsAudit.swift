import AppKit
import Foundation

/// Contracts for the real material dispatch, not a claim of factory accuracy.
@MainActor
enum FoilOpticsAudit {
    typealias Resolver = @MainActor (String, FoilSpec) -> FoilReliefMaterial?

    static func material(_ id: String, _ spec: FoilSpec) -> FoilReliefMaterial? {
        FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture, cardID: id)
    }

    static func verifyRadiantCollection(index: CardIndex) throws {
        var smooth = 0, paper = 0
        for card in index.cards where card.id.hasPrefix("g1-RC") {
            try LocalAudit.require(!FoilAuditPrintings.finishes(for: card, index: index).contains(.reverseHolo),
                "Invented Generations RC reverse counted as audit coverage: \(card.id)")
            let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind)
            if card.rarity == "Common" {
                try LocalAudit.require(resolved.finish == .normal && !resolved.spec.isFoil,
                    "Generations RC common acquired foil: \(card.id)")
                paper += 1
                continue
            }
            try LocalAudit.require(resolved.finish == .radiantCollection
                && resolved.spec.texture == .none && material(card.id, resolved.spec) == nil
                && FoilSheetMaterial(pattern: resolved.spec.pattern, cardID: card.id) == .radiantCollection,
                "Smooth Generations RC acquired engraved relief: \(card.id)")
            smooth += 1
            if card.id == "g1-RC29" {
                let rect = FoilGeometry.artRect(cardID: card.id, in: CGSize(width: 734, height: 1024))
                try LocalAudit.require(resolved.spec.coverage == .artWindow && resolved.spec.border == .paper
                    && abs(rect.minX-30) < 1 && abs(rect.minY-30) < 1
                    && abs(rect.maxX-703) < 1 && abs(rect.maxY-995) < 1,
                    "RC Pikachu yellow rim acquired foil or lost source geometry")
            }
        }
        try LocalAudit.require(smooth == 19 && paper == 13,
            "Generations RC roster changed: \(smooth) foil / \(paper) paper")
        let legendaryTreasures = CardFinishResolver.resolve(cardID: "bw11-RC1", setID: "bw11",
            originalRarity: "Common", tier: .common)
        try LocalAudit.require(legendaryTreasures.spec.pattern == .starSheen,
            "Generations correction changed Legendary Treasures' star sheet")
    }

    static func verifyNeoRouting(index: CardIndex, resolve: Resolver = material) throws {
        var found = Set<String>()
        for card in index.cards {
            for finish in FoilAuditPrintings.finishes(for: card, index: index) + [.normal] {
                let result = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                    originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                    explicitFinish: finish)
                let spec = result.spec
                let actual = resolve(card.id, spec)
                let expected = FoilReliefMaterial.neoShiningCardIDs.contains(card.id) && spec.isFoil
                try LocalAudit.require((actual == .neoShining) == expected,
                                       "Neo metallic dispatch: \(card.id)#\(finish?.rawValue ?? "default")")
                if expected {
                    try LocalAudit.require(spec.coverage == .artSubject && spec.border == .paper,
                                           "Neo grain escaped subject: \(card.id)")
                    found.insert(card.id)
                }
            }
        }
        try LocalAudit.require(found == FoilReliefMaterial.neoShiningCardIDs, "Missing Neo printings")
    }

    static func verifyRidgeScale(columns: Int, maximumLength: Double) throws {
        try LocalAudit.require(columns > 0 && maximumLength.isFinite && maximumLength > 0
            && maximumLength * 240 / Double(columns) < 0.8,
            "Foil facets read as long scratches at 240pt")
    }

    static func verify(index: CardIndex) throws {
        let mur = FoilReliefMaterial.gold(.megaGold)
        try LocalAudit.require(FoilArtworkBalance.entries["base5-6"] != nil
            && FoilArtworkBalance.entries["ex12-17"] == nil,
            "Missing source-bound Cosmos tuning or weak source dimmed")
        try LocalAudit.require(mur.coatingGain(meanLuminance: 0.7) == 0.44
            && mur.coatingGain(meanLuminance: 0.3) == 0.30,
            "MUR dense coating lost artwork protection")
        for preserved in [FoilReliefMaterial.black, .white, .neoShining, .gold(.scarletVioletGold)] {
            try LocalAudit.require(preserved.coatingGain(meanLuminance: 0.3) == 1,
                "Artwork balance changed an unrelated material")
        }
        try verifyAreaLighting()
        for white in [false, true] {
            for level in [0.0, 0.3, 0.6, 1.0] {
                try LocalAudit.require(ScannedEmbossCache.ridgeWeight(light: level, localMean: level, isWhite: white) == 0,
                    "BWR flat ink acquired a full-face carrier")
            }
            try LocalAudit.require(ScannedEmbossCache.ridgeWeight(light: white ? 0 : 1, localMean: 0.5, isWhite: white) == 0,
                "BWR solid lettering acquired engraving")
        }
        let bwrChanges = (0..<ScannedEmbossCache.groupCount).map { group in
            abs(ScannedEmbossCache.response(group: group, tilt: .zero)
                - ScannedEmbossCache.response(group: group, tilt: .init(nx: 0.28, ny: 0)))
        }
        try LocalAudit.require(bwrChanges.filter { $0 > 0.4 }.count >= 8, "BWR lost small-angle ridge response")
        try verifyRadiantCollection(index: index)
        try verifyNeoRouting(index: index)
        try verifySheets(index: index)
        try verifyScanFeatures()
        try verifyDirectionalSheets(index: index)
        try verifyVisibilityMaterials()
        var ordinaryEx = 0, megaEx = 0
        for card in index.cards where card.tier == .doubleRare {
            let spec = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                explicitFinish: .fullArt).spec
            if card.setID.hasPrefix("me") && card.name.hasPrefix("Mega ") {
                try LocalAudit.require(spec.treatment == .megaDoubleRare,
                    "Mega ex routed through ordinary ex: \(card.id)")
                megaEx += 1
            }
            if spec.pattern == .doubleRareSheen { ordinaryEx += 1 }
        }
        try LocalAudit.require(ordinaryEx == 220 && megaEx == 44,
            "Ordinary/Mega ex coverage changed: \(ordinaryEx)/\(megaEx)")
        try verifyDispersion(sample: FoilReliefMaterial.dispersedNormal)
        for angle in [-1.4, -0.2, 0, 0.8, 1.5] {
            let blended = FoilReliefMaterial.blendRidgeDirection(angle, angle + .pi, weight: 0.16)
            try LocalAudit.require(abs(sin(blended - angle)) < 0.000001,
                                   "Opposing ridge axes rotated into a cross scratch")
        }
        let goldPatterns: [FoilPattern] = [.gold, .bwGold, .xyGold, .sunMoonGold,
            .swordShieldGold, .scarletVioletGold, .teraGold, .megaGold]
        for material in [.illustration, .neoShining] + goldPatterns.map({ FoilReliefMaterial.gold($0) }) {
            try verifyRidgeScale(columns: material.columns,
                                 maximumLength: material.facetLength + material.lengthVariation)
            for color in material.reflectionColors {
                guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else {
                    throw LocalAudit.Failure(description: "Cannot inspect foil palette")
                }
                if material.isGold {
                    try LocalAudit.require(rgb.redComponent >= rgb.greenComponent
                        && rgb.greenComponent > rgb.blueComponent, "Gold acquired a rainbow highlight")
                } else if material == .neoShining {
                    try LocalAudit.require(abs(rgb.redComponent - rgb.greenComponent) < 0.001
                        && abs(rgb.greenComponent - rgb.blueComponent) < 0.001, "Neo acquired rainbow stripes")
                }
            }
        }
        for card in index.cards {
            for finish in FoilAuditPrintings.finishes(for: card, index: index) {
                let spec = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                    originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                    explicitFinish: finish).spec
                if let material = material(card.id, spec), material.isEngraved || material.isMicroEtched || material.isLinear {
                    try verifyRidgeScale(columns: material.columns,
                        maximumLength: material.facetLength + material.lengthVariation)
                }
            }
        }
        // Reproduce both reachable regressions: omitted cardID at the render
        // call site, and routing every legacy refractor to the new Neo material.
        let mutations: [Resolver] = [
            { _, spec in FoilReliefMaterial(pattern: spec.pattern, texture: spec.texture) },
            { id, spec in spec.pattern == .refractor ? .neoShining : material(id, spec) },
        ]
        for mutation in mutations {
            var rejected = false
            do { try verifyNeoRouting(index: index, resolve: mutation) } catch { rejected = true }
            try LocalAudit.require(rejected, "Optics guard accepted a dispatch mutation")
        }
        var rejected = false
        do { try verifyRidgeScale(columns: 190, maximumLength: 1.18) } catch { rejected = true }
        try LocalAudit.require(rejected, "Optics guard accepted previous coarse facets")
        rejected = false
        do {
            try verifyDispersion { row, column, phase, _ in
                sin(Double(row) / 400 * 39 + sin(Double(column) / 280 * 22 + phase)) * 2.4
            }
        } catch { rejected = true }
        try LocalAudit.require(rejected, "Optics guard accepted coarse periodic normals")
        rejected = false
        do {
            try verifySheets(index: index) { pattern, id in
                pattern == .cosmos ? nil : FoilSheetMaterial(pattern: pattern, cardID: id)
            }
        } catch { rejected = true }
        try LocalAudit.require(rejected, "Optics guard accepted legacy Cosmos fallback")
        print("PASS optical contracts: catalogue routing, sheet isolation, scan-feature groups, directional sheets, etched scales, visibility gain, 8 Neo subjects, 8 warm gold families, 6 rejected mutations; wallet untouched")
    }

    static func verifyDispersion(sample: (Int, Int, Double, Double) -> Double) throws {
        var change = 0.0
        for row in 0..<32 {
            for column in 0..<64 {
                let a = sample(row, column, 0.7, 0)
                let b = sample(row, column + 1, 0.7, 0)
                change += abs(a - b)
            }
        }
        try LocalAudit.require(change / 2048 > 0.5, "Normals form large continuous scanlines")
    }

    static func verifyAreaLighting() throws {
        try verifyReliefNeighbourhoods()
        for nx in stride(from: -1.0, through: 1.0, by: 0.1) {
            for ny in stride(from: -1.0, through: 1.0, by: 0.1) {
                for source in [FoilAreaLighting.source(nx: nx, ny: ny),
                               FoilAreaLighting.directionalSource(nx: nx, ny: ny)] {
                    try LocalAudit.require(source.x < 0 || source.x > 1 || source.y < 0 || source.y > 1,
                                           "Visible light source moved onto the card")
                }
            }
        }
        for angle in stride(from: -4.0, through: 4.0, by: 0.4) {
            for phase in stride(from: 0.0, through: 6.0, by: 0.3) {
                func energy(_ x: Double, _ y: Double) -> Double {
                    FoilAreaLighting.facetIllumination(x: x, y: y, phase: phase, angle: angle)
                }
                let center = energy(0.5, 0.5)
                let corners = [energy(0, 0), energy(1, 0), energy(0, 1), energy(1, 1)]
                try LocalAudit.require(abs(center - corners.reduce(0, +) / 4) < 0.000001,
                                       "Foil light acquired an interior hotspot")
                try LocalAudit.require(corners.allSatisfy { (0...1).contains($0) }, "Unbounded foil light")
            }
        }
        let phases = (0..<100).map { Double($0) * .pi * 2 / 100 }
        let changes = phases.map {
            abs(FoilAreaLighting.facetIllumination(x: 0.5, y: 0.5, phase: $0, angle: 0)
                - FoilAreaLighting.facetIllumination(x: 0.5, y: 0.5, phase: $0, angle: 1.4))
        }
        try LocalAudit.require(changes.filter { $0 > 0.2 }.count > 25,
                               "Removing the hotspot also removed local glints")
        print("PASS area lighting: off-card surface sources, no central illumination peak, independent moving glints")
    }

    static func verifyReliefNeighbourhoods() throws {
        var nearby = 0.0, distant = 0.0, count = 0.0
        for columns in [24.0, 28, 32, 38] {
            for seed in 1...12 {
                for row in 0..<12 {
                    for column in 0..<12 {
                        let x = (Double(column) + 0.3) / 12
                        let y = (Double(row) + 0.7) / 12
                        func phase(_ dx: Double, _ dy: Double) -> Double {
                            FoilAreaLighting.neighbourhoodPhase(x: x + dx, y: y + dy,
                                                               seed: UInt64(seed), columns: columns)
                        }
                        let a = phase(0, 0)
                        try LocalAudit.require(a.isFinite, "Invalid neighbourhood phase")
                        nearby += cos(a - phase(0.001, 0.001))
                        distant += cos(a - phase(0.17, 0.13))
                        count += 1
                    }
                }
            }
        }
        try LocalAudit.require(nearby / count > 0.95, "Relief neighbours became independent noise")
        try LocalAudit.require(abs(distant / count) < 0.12, "Relief acquired a card-wide coherent light field")
        try LocalAudit.require(FoilReliefMaterial.illustration.lightNeighbourhoodColumns
            != FoilReliefMaterial.gold(.megaGold).lightNeighbourhoodColumns, "Materials lost their grain scale")
        try LocalAudit.require(FoilReliefMaterial.neoShining.lightNeighbourhoodColumns == nil,
                               "Etched patches leaked into unetched metallic subjects")
        print("PASS relief contrast: correlated neighbours, decorrelated distant regions, distinct grain scales")
    }

    static func verifyVisibilityMaterials() throws {
        try LocalAudit.require(DoubleRareStarSheet.motifs.count == 260
            && Set(DoubleRareStarSheet.motifs.map(\.kind)).count == 5,
            "Ordinary ex lost its mixed star sheet")
        let starChanges = DoubleRareStarSheet.motifs.map {
            abs(DoubleRareStarSheet.response(phase: $0.phase, tilt: TiltVector(nx: 0, ny: 0))
                - DoubleRareStarSheet.response(phase: $0.phase, tilt: TiltVector(nx: 0.6, ny: -0.4)))
        }
        try LocalAudit.require(starChanges.filter { $0 > 0.4 }.count > 70,
            "Ordinary ex stars became static or imperceptible")
        try LocalAudit.require(FoilSheetMaterial(pattern: .teraSheen, cardID: "sv1-32") == nil,
            "Tera engraving acquired an ordinary ex star sheet")
        try LocalAudit.require(FoilReliefMaterial(pattern: .rainbowSplash) == .engraved(.rainbowSplash, .swordShieldEtched)
            && FoilReliefMaterial(pattern: .stone) == .engraved(.stone, .embossed)
            && FoilSheetMaterial(pattern: .doubleRareSheen, cardID: "cel30-102") == .doubleRare,
            "Weak-material dispatch returned to attenuated legacy layers")
        let amazing = FoilReliefMaterial.engraved(.rainbowSplash, .swordShieldEtched)
        try LocalAudit.require(amazing.imageResponse(light: 0.6, edge: 0) < 0.2
            && amazing.imageResponse(light: 0.6, edge: 1) > 0.8,
            "Amazing Rare amplified flat ink as strongly as detailed foil")
        func checkGain(_ gain: (Double) -> Double) throws {
            try LocalAudit.require(gain(0.28) - gain(0) > 0.2 && gain(0.88) > 1.8,
                "Etched material has no small-angle highlight gain")
        }
        try checkGain(FoilReliefMaterial.illustration.highlightGain)
        var rejected = false
        do { try checkGain { _ in 1 } } catch { rejected = true }
        try LocalAudit.require(rejected, "Visibility guard accepted inert SAR gain")
    }

    static func verifyDirectionalSheets(index: CardIndex) throws {
        let ballResponses = stride(from: -1.0, through: 1.0, by: 0.05).map {
            DimensionalBallSheet.response(x: 0.4, y: 0.3, tilt: TiltVector(nx: $0, ny: 0))
        }
        try LocalAudit.require((ballResponses.max() ?? 0) > 0.65
            && (ballResponses.min() ?? 1) < 0.08
            && zip(ballResponses, ballResponses.dropFirst()).allSatisfy { abs($0 - $1) < 0.12 },
            "3D foil balls lost their smooth angular reveal")
        let horizontal = FoilDirectionalSheet.point(pattern: .tinsel, along: 0.7, across: 0.3)
        let vertical = FoilDirectionalSheet.point(pattern: .verticalLine, along: 0.7, across: 0.3)
        try LocalAudit.require(horizontal == CGPoint(x: 0.7, y: 0.3)
            && vertical == CGPoint(x: 0.3, y: 0.7), "Directional foil families collapsed")
        try LocalAudit.require(FoilReliefMaterial(pattern: .waterWeb, texture: .none) == .linear(.waterWeb)
            && FoilReliefMaterial(pattern: .waterWeb, texture: .sunMoonEtched) == .engraved(.waterWeb, .sunMoonEtched),
            "Unetched and etched water-web printings collapsed")
        guard let snivy = index.card("bw11-RC1") else { throw LocalAudit.Failure(description: "Missing RC sample") }
        let spec = CardFinishResolver.resolve(cardID: snivy.id, setID: snivy.setID,
            originalRarity: snivy.rarity, tier: snivy.tier, visualKind: snivy.visualKind,
            explicitFinish: .radiantCollection).spec
        try LocalAudit.require(spec.pattern == .starSheen && spec.texture == .none,
            "Radiant Collection acquired invented embossing")
    }

    static func verifySheets(index: CardIndex,
        resolve: (FoilPattern, String) -> FoilSheetMaterial? = { FoilSheetMaterial(pattern: $0, cardID: $1) }) throws {
        let expected: [(String, CardFinish, FoilSheetMaterial?)] = [
            ("cel25-1", .holo, .celebration), ("cel25-5", .holo, .celebration),
            ("cel25-25", .holo, nil), ("cel25-1", .normal, nil),
            ("base4-1", .holo, .cosmos), ("ex12-1", .reverseHolo, .cosmos),
            ("hgss1-111", .holo, .legend), ("ex10-113", .shiny, .goldStar),
            ("ex13-102", .shiny, .refractorGoldStar), ("neo4-107", .shiny, nil),
            ("ex11-1", .holo, .deltaSpecies), ("ex15-1", .holo, .deltaSpecies),
            ("ex10-1", .reverseHolo, .dimensionalBalls),
        ]
        for (id, finish, sheet) in expected {
            guard let card = index.card(id) else { throw LocalAudit.Failure(description: "Missing sheet sample \(id)") }
            let spec = CardFinishResolver.resolve(cardID: id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                explicitFinish: finish).spec
            try LocalAudit.require(resolve(spec.pattern, id) == sheet,
                "Sheet routing regression: \(id)#\(finish.rawValue)")
            if sheet == .dimensionalBalls {
                try LocalAudit.require(spec.coverage == .artBackground,
                    "Unseen Forces balls were projected onto opaque subject ink")
            }
        }
    }

    static func verifyScanFeatures() throws {
        let side = 64
        // One bright fleck, a continuous ink edge, and a flat fill. Only the
        // fleck is permitted. Coordinates must stay attached to source pixels.
        var source = [Double](repeating: 0.10, count: side * side)
        for y in 10..<13 { for x in 19..<22 { source[y * side + x] = 0.95 } }
        for y in 4..<60 { source[y * side + 42] = 0.95 }
        let actual = FoilScanGlintCache.featureAlpha(light: source, width: side, height: side)
        let groups = (0..<3).map {
            FoilScanGlintCache.featureAlpha(light: source, width: side, height: side, group: $0)
        }
        for p in actual.indices {
            try LocalAudit.require(groups.reduce(0) { $0 + Int($1[p]) } == Int(actual[p]),
                "Glint groups duplicate or move a source feature")
        }
        let fleckGroups = groups.filter { $0[11 * side + 20] > 0 }
        try LocalAudit.require(fleckGroups.count == 1
            && (10..<13).allSatisfy { y in (19..<22).allSatisfy { x in fleckGroups[0][y * side + x] > 0 } },
            "One physical fleck was split between lighting groups")
        for group in 0..<3 {
            let energies = stride(from: -1.0, through: 1.0, by: 0.1).map {
                FoilScanGlintCache.reflectionEnergy(group: group, x: $0, y: 0)
            }
            try LocalAudit.require((energies.max() ?? 0) > 0.95 && (energies.min() ?? 1) == 0,
                "Source flecks do not change brightness with tilt")
        }
        try LocalAudit.require(actual[11 * side + 20] > 100, "Source glint lost")
        try LocalAudit.require(actual[32 * side + 42] == 0 && actual[45 * side + 20] == 0,
            "Ink edge or empty fill acquired foil")
        try LocalAudit.require(FoilScanGlintCache.featureAlpha(light: Array(repeating: 0.8, count: side * side),
            width: side, height: side).allSatisfy { $0 == 0 }, "Flat scan acquired invented orbs")
        try LocalAudit.require(FoilScanGlintCache.featureAlpha(light: [], width: 2, height: 2).isEmpty,
            "Malformed feature input was accepted")
    }
}
