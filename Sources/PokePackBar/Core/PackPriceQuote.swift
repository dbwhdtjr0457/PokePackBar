import Foundation

struct PackPriceQuote: Codable, Sendable {
    enum Basis: String, Codable, Sendable { case market, economyFloor, expectedValue, fallback }
    let marketUSD: Double?
    let marketDate: String?
    let productURL: String?
    let expectedCardValueUSD: Double
    let economyFloorUSD: Double
    let baseTokens: Int
    let basis: Basis
}

extension PackPricing {
    static func quote(setID: String, index: CardIndex,
                      prices: CardPrices? = CardPrices.shared,
                      marketPrices: PackMarketPrices? = PackMarketPrices.shared) -> PackPriceQuote {
        let value = MarketEconomy.packValueUSD(setID: setID, index: index, prices: prices)
        let floor = value * MarketEconomy.packMargin
        let market = marketPrices?.entry(setID: setID)
        let usd = max(floor, market?.usd ?? 0)
        let basis: PackPriceQuote.Basis
        if usd <= 0 { basis = .fallback }
        else if let market { basis = market.usd >= floor ? .market : .economyFloor }
        else { basis = .expectedValue }
        return PackPriceQuote(marketUSD: market?.usd, marketDate: market == nil ? nil : (market?.asOf ?? marketPrices?.asOf),
            productURL: market?.url, expectedCardValueUSD: value, economyFloorUSD: floor,
            baseTokens: usd > 0 ? MarketEconomy.tokens(usd: usd, prices: prices)
                : fallbackPrice(setID: setID, index: index), basis: basis)
    }
}
