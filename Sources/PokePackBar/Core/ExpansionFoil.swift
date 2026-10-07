import Foundation

/// Audited new printings. Stable collection keys are independent of optical
/// materials; a replacement original invalidates image-bound registration.
enum ExpansionFoil {
    struct Entry: Decodable, Sendable {
        let sha256: String
        let width: Int
        let height: Int
        let rarity: String
        let treatment: String
        let goldFrame: [[[Double]]]?
    }
    enum Ball: String, Decodable, Sendable, CaseIterable {
        case pokeBall, friendBall, loveBall, quickBall, duskBall, teamRocket
    }
    struct Product: Decodable, Sendable {
        let productID: Int
        let url: String
        let marketUSD: Double?
    }
    struct Parallel: Decodable, Sendable {
        let pattern: Ball
        let productID: Int
        let url: String
        let marketUSD: Double?
        let energy: Product
    }
    private struct Manifest: Decodable {
        let version: Int
        let cards: [String: Entry]
        let ascendedParallels: [String: Parallel]
    }
    private static let manifest: Manifest? = {
        guard let url = AppResources.bundle?.url(forResource: "expansion-foil", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(Manifest.self, from: data), result.version == 1 else { return nil }
        return result
    }()
    static let entries: [String: Entry] = (manifest?.cards ?? [:]).filter { id, entry in
        guard let art = CardArtLibrary.entries[id], entry.sha256 == art.sha256,
              entry.width == min(art.width, art.height), entry.height == max(art.width, art.height) else { return false }
        return (entry.goldFrame ?? []).allSatisfy { contour in
            contour.count >= 3 && contour.allSatisfy { point in
                point.count == 2 && point.allSatisfy { $0.isFinite && (0...1).contains($0) }
            }
        }
    }
    static let parallels: [String: Parallel] = manifest?.ascendedParallels ?? [:]

    static func spec(cardID: String, finish: CardFinish) -> FoilSpec? {
        if finish == .reverseHolo, parallels[cardID] != nil {
            return FoilSpec(coverage: .outsideArt, pattern: .mirror, texture: .none,
                            border: .silver, intensity: 0.62, treatment: .ascendedEnergy)
        }
        guard let entry = entries[cardID] else { return nil }
        switch (entry.treatment, finish) {
        case ("classic30", .celebrationsClassic):
            return FoilSpec(coverage: .fullCard, pattern: .confetti, texture: .none,
                            border: .gold, intensity: 0.76, treatment: .classic30)
        case ("pikachu30", .fullArt):
            return FoilSpec(coverage: .fullCard, pattern: .fireworks, texture: .none,
                            border: .silver, intensity: 0.74, treatment: .pikachu30)
        case ("futuristic30", .etched):
            return FoilSpec(coverage: .fullCard, pattern: .futuristic, texture: .none,
                            border: .silver, intensity: 0.78, treatment: .futuristic30)
        case ("rgb30", .etched):
            return FoilSpec(coverage: .fullCard, pattern: .futuristic, texture: .none,
                            border: .silver, intensity: 0.64, treatment: .rgb30)
        case ("megaDoubleRare", .fullArt):
            return FoilSpec(coverage: .fullCard, pattern: .mirage, texture: .scarletVioletEtched,
                            border: .silver, intensity: 0.60, treatment: .megaDoubleRare)
        default: return nil
        }
    }

    @MainActor
    static func verify(index: CardIndex) throws {
        try LocalAudit.require(entries.count == 852 && parallels.count == 140, "Incomplete expansion foil manifest")
        var treatments: [FoilTreatment: Int] = [:]
        for id in entries.keys {
            guard let card = index.card(id) else { throw LocalAudit.Failure(description: "Unknown foil card \(id)") }
            let resolved = CardFinishResolver.resolve(cardID: id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind)
            if let treatment = resolved.spec.treatment { treatments[treatment, default: 0] += 1 }
            if id.hasPrefix("cel30c-") {
                try LocalAudit.require(resolved.spec.border == .gold && !(entries[id]?.goldFrame ?? []).isEmpty,
                                       "30th gold border lost: \(id)")
            }
        }
        try LocalAudit.require(treatments[.classic30] == 30 && treatments[.pikachu30] == 30
            && treatments[.futuristic30] == 2 && treatments[.rgb30] == 3
            && treatments[.megaDoubleRare] == 28, "New expansion treatments merged")
        try LocalAudit.require(CardFinishResolver.resolve(cardID: "cel25c-4", setID: "cel25",
            originalRarity: "Classic Collection", tier: .superRare).spec.border == .silver, "25th was recolored gold")
        try LocalAudit.require(Set(parallels.values.map(\.pattern)) == Set(Ball.allCases), "Missing Ascended motif")
        for id in parallels.keys {
            try LocalAudit.require(index.card(id)?.visualKind?.supertype == .pokemon, "Trainer has ball foil: \(id)")
        }
        guard let prices = CardPrices.loadBundled() else { throw LocalAudit.Failure(description: "Missing printing prices") }
        for id in parallels.keys {
            for finish in [CardFinish.reverseHolo, .patternedReverse] {
                try LocalAudit.require(prices.exactPrice(cardID: id, finish: finish) != nil, "Parallel price missing: \(id)#\(finish)")
            }
        }
        var random = PackSeedGenerator(seed: 302026)
        var pity = 0
        var seen = Set<String>()
        var energySeen = Set<String>()
        for _ in 0..<5_000 {
            let pack = PackOpening.draw(setID: "me2pt5", index: index, alreadyOwned: [],  // 혜택 제외: 검사는 혜택 없는 기본 개봉을 본다
                pity: &pity, mode: .realistic, using: &random)
            for card in pack.cards {
                if card.finish == .patternedReverse {
                    try LocalAudit.require(parallels[card.id] != nil, "Nonexistent ball printing drawn")
                    seen.insert(card.id)
                }
                if card.finish == .reverseHolo && parallels[card.id] != nil { energySeen.insert(card.id) }
            }
        }
        try LocalAudit.require(seen == Set(parallels.keys) && energySeen == seen, "Unreachable Ascended parallels")
        print("PASS expansion foil: 852 cards, 30 gold masks, 17 material specs; 5,000 packs reach all 280 parallels with exact prices")
    }
}
