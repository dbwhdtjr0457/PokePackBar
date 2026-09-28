import Foundation

/// Executable regression checks for developer machines without XCTest.
@MainActor
enum ConfirmedFoilAudit {
    static func verify(index: CardIndex) throws {
        try FoilSubjectMasks.verify()
        try PhysicalFoilMarks.verify()
        func resolved(_ id: String, finish: CardFinish? = nil) throws -> ResolvedCardFinish {
            guard let card = index.card(id) else { throw LocalAudit.Failure(description: "Missing \(id)") }
            return CardFinishResolver.resolve(cardID: id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
                explicitFinish: finish)
        }
        for finish in [nil, CardFinish.holo] {
            let mew = try resolved("cel25-25", finish: finish)
            try LocalAudit.require(mew.finish == .holo && mew.spec.pattern == .swordShieldGold
                && mew.spec.coverage == .fullCard && mew.spec.border == .gold,
                "Gold Mew lost legacy-key-compatible gold optics")
        }
        try LocalAudit.require(try resolved("cel25-11").spec.pattern == .celebrationSheen,
                               "Ordinary Mew inherited secret foil")
        try LocalAudit.require(try resolved("cel25-25", finish: .normal).spec.coverage == .none,
                               "Explicit paper printing was overridden")
        guard let art = FoilGeometry.entries["cel25-5"]?.illustration else {
            throw LocalAudit.Failure(description: "Missing full-art Pikachu bounds")
        }
        try LocalAudit.require(art.minY < 0.04 && art.maxY > 0.96
            && art.minX > 0.03 && art.maxX < 0.97, "Pikachu artwork or paper frame clipped incorrectly")
        let pikachu = try resolved("cel25-5")
        try LocalAudit.require(pikachu.spec.coverage == .artWindow && pikachu.spec.border == .paper
            && pikachu.spec.texture == .none, "Untextured full-art Pikachu material changed")
        for number in 106...113 {
            let card = try resolved("neo4-\(number)")
            try LocalAudit.require(card.spec.coverage == .artSubject && card.spec.border == .paper,
                                   "Neo Shining background or paper frame foiled: \(number)")
        }
        for (set, count) in [("ex11", 18), ("ex15", 12)] {
            for number in 1...count {
                try LocalAudit.require(try resolved("\(set)-\(number)").spec.coverage == .artSubjectAndBorder,
                                       "Delta background foiled: \(set)-\(number)")
            }
        }
        let patterns: Set<FoilPattern> = [.vstarSheen, .shinyGX, .shinyV, .shinyVMAX, .shinyEx, .teraShinyEx]
        var reliefCount = 0
        var legendaryReverseCount = 0
        var parallelCount = 0
        for card in index.cards {
            let result = try resolved(card.id)
            if patterns.contains(result.spec.pattern) {
                try LocalAudit.require(FoilReliefMaterial(pattern: result.spec.pattern,
                    texture: result.spec.texture) != nil, "Missing relief: \(card.id)")
                reliefCount += 1
            }
            let finishes = FoilAuditPrintings.finishes(for: card, index: index)
            if card.id.hasPrefix("bw11-") && finishes.contains(.reverseHolo) {
                try LocalAudit.require(!card.id.hasPrefix("bw11-RC")
                    && [CardTier.common, .uncommon, .rare].contains(card.tier),
                    "Invalid Legendary Treasures reverse: \(card.id)")
                legendaryReverseCount += 1
            }
            for (finish, masterOnly) in [(CardFinish.pokeBall, false), (.masterBall, true)] {
                let eligible = !PackOpening.prismaticParallelCandidates(setID: card.setID,
                    pool: [card.tier: [card.id]], masterBallOnly: masterOnly).isEmpty
                try LocalAudit.require(finishes.contains(finish) == eligible,
                                       "Audit/opening parallel mismatch: \(card.id)")
                if eligible { parallelCount += 1 }
            }
        }
        try LocalAudit.require(reliefCount == 106, "Unexpected corrected-relief coverage: \(reliefCount)")
        try LocalAudit.require(legendaryReverseCount == 71, "Legendary reverse audit omissions")
        try LocalAudit.require(parallelCount == 471, "Ball audit range drift: \(parallelCount)")
        try LocalAudit.require(try resolved("cel30c-14").spec.treatment == .classic30,
                               "Reprint inherited original Shining mask")
        print("PASS confirmed foil fixes: 2 Celebrations exceptions, 38 subject mappings, \(reliefCount) relief printings, 71 Legendary reverses, \(parallelCount) valid ball parallels; wallet untouched")
    }
}
