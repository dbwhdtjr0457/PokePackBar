import Foundation

/// Pure preparation: no wallet writes. Safe to discard on cancellation/conflict.
struct PreparedPackBatch: Sendable {
    /// 그리다 멈춘 이유. 팩은 하나도 소비되지 않았다.
    enum Failure: LocalizedError {
        case incompleteCatalogue
        var errorDescription: String? { L.current.packCatalogueIncomplete }
    }

    let packs: [OpenedCards]
    let printings: [CardPrintingKey]
    let records: [OpeningRecord]
    let pity: Int

    static func draw(setID: String, count: Int, index: CardIndex, owned: Set<String>,
                     mode: OpeningMode, perks: DexPerks, pity: Int,
                     seeds: [UInt64]?) throws -> Self {
        let era = index.era(setID)
        let expectedCards = PackRecipe.forSet(setID, era: era).contents.gameCardCount
        // A batch uses one immutable price/rules snapshot, not one recalculation per pack.
        let prices = CardPrices.shared
        let quote = PackPricing.quote(setID: setID, index: index, prices: prices)
        let digest = OpeningRules.catalogueDigest
        var alreadyOwned = owned
        var currentPity = mode == .realistic ? 0 : pity
        var packs: [OpenedCards] = []
        var printings: [CardPrintingKey] = []
        var records: [OpeningRecord] = []
        packs.reserveCapacity(count)
        printings.reserveCapacity(count * expectedCards)
        records.reserveCapacity(min(count, OpeningRules.historyLimit))

        for offset in 0..<count {
            if offset.isMultiple(of: 32) { try Task.checkCancellation() }
            let seed = seeds?[offset] ?? UInt64.random(in: .min ... .max)
            var generator = PackSeedGenerator(seed: seed)
            let pityBefore = currentPity
            let opened = PackOpening.draw(setID: setID, index: index,
                alreadyOwned: alreadyOwned, perks: perks, pity: &currentPity,
                mode: mode, using: &generator)
            guard opened.cards.count == expectedCards else {
                throw Failure.incompleteCatalogue
            }
            let packPrintings = opened.cards.map { CardPrintingKey(cardID: $0.id, finish: $0.finish) }
            // Preserve the existing history limit without allocating records we will discard.
            if offset >= count - OpeningRules.historyLimit {
                records.append(OpeningRecord(id: UUID(), openedAt: Date(), setID: setID, seed: String(seed),
                    rulesVersion: OpeningRules.version, catalogueDigest: digest,
                    mode: mode, hitOddsBonus: perks.hitOdds, pityBefore: pityBefore, pityAfter: currentPity,
                    variant: opened.variant, printings: packPrintings,
                    supplement: PackSupplement.contents(setID: setID, era: era,
                                                        variant: opened.variant, cards: opened.cards),
                    cardPriceDate: prices?.asOf, printingPriceDate: prices?.printingAsOf,
                    priceSnapshotDigest: prices?.snapshotDigest, packQuote: quote))
            }
            packs.append(opened)
            for (card, printing) in zip(opened.cards, packPrintings) where !card.isSupplementalEnergy {
                printings.append(printing)
                alreadyOwned.insert(card.id)
            }
        }
        return Self(packs: packs, printings: printings, records: records, pity: currentPity)
    }
}

/// Calculate once away from SwiftUI body; retain physical order and special-pack boundaries.
struct PackPresentation: Sendable {
    static let imageWindow = 24
    let cards: [PulledCard]
    let packCardCounts: [Int]
    let variants: [PackVariant]
    let supplements: [PackSupplement]
    let summaryCards: [PulledCard]
    /// Results-screen orders. The reveal itself keeps the physical pack order;
    /// only the summary is re-sorted so the best pulls are found at a glance.
    let summaryByPrice: [PulledCard]
    let summaryByRarity: [PulledCard]
    let newCount: Int
    let worthUSD: Double
    let specialStarts: [Int: PackVariant]
    let specialVariants: [PackVariant]

    init(packs: [OpenedCards], setID: String, era: PackEra) {
        var cards: [PulledCard] = []
        var counts: [Int] = []
        var supplements: [PackSupplement] = []
        var starts: [Int: PackVariant] = [:]
        for pack in packs {
            let supplement = PackSupplement.contents(setID: setID, era: era,
                                                     variant: pack.variant, cards: pack.cards)
            let displayed = PackOpening.revealOrder(pack.cards)
                + SupplementalEnergyCard.cards(setID: setID, era: era, supplement: supplement,
                                              expansionCards: pack.cards)
            if pack.variant.isSpecialHit { starts[cards.count] = pack.variant }
            cards.append(contentsOf: displayed)
            counts.append(displayed.count)
            supplements.append(supplement)
        }
        self.cards = cards
        self.packCardCounts = counts
        self.variants = packs.map(\.variant)
        self.supplements = supplements
        self.specialStarts = starts
        self.specialVariants = packs.map(\.variant).filter(\.isSpecialHit)
        self.newCount = cards.filter(\.isNew).count
        let collectible = cards.filter { !$0.isSupplementalEnergy }
        let energy = cards.filter(\.isSupplementalEnergy)
        self.summaryCards = Array(collectible.reversed()) + energy
        // Price each card once here, not in the SwiftUI body: bulk openings
        // can hold thousands of cards. Ties fall back to the other key, then
        // to the later-revealed card first, matching the previous order.
        let priced = collectible.enumerated().map { offset, card in
            (card: card, offset: offset,
             usd: MarketEconomy.usd(cardID: card.id, finish: card.finish, prices: CardPrices.shared))
        }
        self.worthUSD = priced.reduce(0) { $0 + $1.usd }
        self.summaryByPrice = priced.sorted { a, b in
            if a.usd != b.usd { return a.usd > b.usd }
            if a.card.tier.rank != b.card.tier.rank { return a.card.tier.rank > b.card.tier.rank }
            return a.offset > b.offset
        }.map(\.card) + energy
        self.summaryByRarity = priced.sorted { a, b in
            if a.card.tier.rank != b.card.tier.rank { return a.card.tier.rank > b.card.tier.rank }
            if a.usd != b.usd { return a.usd > b.usd }
            return a.offset > b.offset
        }.map(\.card) + energy
    }

    func imageIDs(at position: Int) -> [String] {
        guard cards.indices.contains(position) else { return [] }
        return cards[position..<min(cards.count, position + Self.imageWindow)].map(\.id)
    }
}
