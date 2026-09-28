import Foundation

/// Runs before the application or real wallet starts, including on CLI-only Macs.
@MainActor
enum PriceSnapshotAudit {
    static func verify(index: CardIndex) throws {
        guard let prices = CardPrices.loadBundled(), let packs = PackMarketPrices.loadBundled() else {
            throw LocalAudit.Failure(description: "Missing bundled market data")
        }
        for color in ["R", "G", "B"] {
            let id = "cel30-\(color)_RGB"
            guard let card = index.card(id) else { throw LocalAudit.Failure(description: "Missing \(id)") }
            let finish = CardFinishResolver.resolve(cardID: id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind).finish
            guard let value = prices.exactPrice(cardID: id, finish: finish) else {
                throw LocalAudit.Failure(description: "RGB has no exact quote: \(id)#\(finish)")
            }
            try LocalAudit.require(value > 0 && prices.price(id) == value, "RGB representative/printing mismatch: \(id)")
            try LocalAudit.require(MarketEconomy.usd(CardPrintingKey(cardID: id, finish: finish), prices: prices) == value,
                                   "RGB sale valuation still falls back")
            try LocalAudit.require(prices.sourceURL(cardID: id, finish: finish)?.hasPrefix("https://") == true,
                                   "RGB quote lost source URL")
            try LocalAudit.require(!prices.sourceDate(cardID: id, finish: finish).isEmpty, "RGB quote has no date")
            let tooltip = L(.ko).cardPriceSource(prices, cardID: id, finish: finish)
            if prices.isReference(cardID: id, finish: finish) {
                try LocalAudit.require(tooltip.contains("실거래 기반 참고가") && !tooltip.contains("TCGplayer 시장가"),
                                       "Reference presented as TCGplayer market")
            }
            print("\(id)#\(finish.rawValue): USD \(value), \(prices.sourceDate(cardID: id, finish: finish))")
        }
        guard let mixed = CardPrices.decode(Data("""
          {"version":5,"asOf":"2026-09-01","currency":"USD","krwPerUsd":1300,
           "prices":{"sample-1":4000},"priceKinds":{"sample-1":"completed-sales-estimate"},
           "priceDates":{"sample-1":"2026-09-23"},"priceSources":{"sample-1":"https://example.org/reference"},
           "printingPrices":{"sample-1#normal":1},"printingKinds":{"sample-1#normal":"market"},
           "printingDates":{"sample-1#normal":"2026-09-22"},"printingSources":{"sample-1#normal":"https://example.org/market"}}
          """.utf8)) else { throw LocalAudit.Failure(description: "Mixed provenance decode failed") }
        try LocalAudit.require(!mixed.isReference(cardID: "sample-1", finish: .normal), "Market quote marked reference")
        for finish: CardFinish? in [nil, .etched] {
            try LocalAudit.require(mixed.isReference(cardID: "sample-1", finish: finish), "Fallback provenance lost")
            try LocalAudit.require(mixed.sourceDate(cardID: "sample-1", finish: finish) == "2026-09-23", "Fallback date lost")
            try LocalAudit.require(mixed.sourceURL(cardID: "sample-1", finish: finish) == "https://example.org/reference", "Fallback source lost")
        }
        try LocalAudit.require(L(.ko).cardPriceSource(mixed, cardID: "sample-1", finish: .normal).contains("TCGplayer"),
                               "Primary market tooltip lost")
        try LocalAudit.require(packs.price(setID: "cel30") != nil, "30th booster price missing")
        // Validate exactly the same bundled payload pair as the import workflow.
        guard let resources = AppResources.bundle,
              let cardsURL = resources.url(forResource: "card-prices", withExtension: "json"),
              let packsURL = resources.url(forResource: "pack-prices", withExtension: "json") else {
            throw LocalAudit.Failure(description: "Missing snapshot resources")
        }
        let object: [String: Any] = ["schemaVersion": 1,
            "cardPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: cardsURL)),
            "packPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: packsURL))]
        _ = try PriceSnapshotStore.validate(JSONSerialization.data(withJSONObject: object))
        let missing = index.cards.filter { prices.price($0.id) == nil }
        try LocalAudit.require(missing.isEmpty, "Unquoted catalogue cards: \(missing.prefix(5).map(\.id).joined(separator: ", "))")
        print("PASS price snapshot: RGB, market/reference provenance, sale lookup, import validation; \(prices.printingCount) printings; \(missing.count) unquoted cards; wallet untouched")
    }
}
