import Foundation

/// Enumerate diagnostic printings from the same eligibility rules as opening.
/// A successful render of an invented parallel is not catalogue coverage.
enum FoilAuditPrintings {
    static func finishes(for card: CardEntry, index: CardIndex) -> [CardFinish?] {
        var finishes: [CardFinish?] = [nil]
        if ExpansionFoil.parallels[card.id] != nil { finishes.append(.patternedReverse) }
        let recipe = PackRecipe.forSet(card.setID, era: index.era(card.setID))
        let isOrdinary = [CardTier.common, .uncommon, .rare].contains(card.tier)
        let hasRegularReverse = recipe.slots.contains { $0.kind == .reverseHolo }
        let hasLegendaryReverse = recipe.slots.contains { $0.kind == .legendaryTreasuresReverse }
        let pool = [card.tier: [card.id]]
        let regularReversePool = PackOpening.slotPool(setID: card.setID, slot: .reverseHolo,
                                                     pool: pool, index: index)
        let inRegularReversePool = regularReversePool[card.tier]?.contains(card.id) == true
        if (hasRegularReverse && inRegularReversePool && (isOrdinary || card.rarity == "Rare Holo"))
            || (hasLegendaryReverse && isOrdinary && !card.id.hasPrefix("bw11-RC")) {
            finishes.append(.reverseHolo)
        }
        // Pass just this card through the actual opening filter. Do not copy
        // its collector-number limits here where they could drift again.
        for (finish, masterOnly) in [(CardFinish.pokeBall, false), (.masterBall, true)] {
            if !PackOpening.prismaticParallelCandidates(setID: card.setID, pool: pool,
                                                        masterBallOnly: masterOnly).isEmpty {
                finishes.append(finish)
            }
        }
        return finishes
    }
}
