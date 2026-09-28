import XCTest
@testable import PokePackBar

final class PackMarketPriceTests: XCTestCase {

    func testBundledSnapshotContainsManyRealBoosterPrices() throws {
        let snapshot = try XCTUnwrap(PackMarketPrices.loadBundled())
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertFalse(snapshot.asOf.isEmpty)
        XCTAssertGreaterThan(snapshot.price(setID: "base1") ?? 0, 0)
        XCTAssertGreaterThan(snapshot.price(setID: "sv1") ?? 0, 0)
    }

    func testUnknownAndNonPositivePricesFallBack() throws {
        let snapshot = try XCTUnwrap(PackMarketPrices.decode(Data("""
            {"version":1,"asOf":"2026-09-22","currency":"USD","source":"fixture",
             "packs":{"valid":{"usd":5.25,"productID":1,"productName":"Pack","url":"https://example.test"},
                      "zero":{"usd":0,"productID":2,"productName":"Pack","url":"https://example.test"}}}
            """.utf8)))

        XCTAssertEqual(snapshot.price(setID: "valid"), 5.25)
        XCTAssertNil(snapshot.price(setID: "zero"))
        XCTAssertNil(snapshot.price(setID: "missing"))
    }

    func testPackPricingUsesSealedQuoteBeforeExpectedCardValue() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let cardPrices = try XCTUnwrap(CardPrices.loadBundled())
        let snapshot = try XCTUnwrap(PackMarketPrices.decode(Data("""
            {"version":1,"asOf":"2026-09-22","currency":"USD","source":"fixture",
             "packs":{"sv1":{"usd":5000,"productID":1,"productName":"Pack","url":"https://example.test"}}}
            """.utf8)))

        XCTAssertEqual(
            PackPricing.basePrice(setID: "sv1", index: index, prices: cardPrices,
                                  marketPrices: snapshot),
            MarketEconomy.tokens(usd: 5000, prices: cardPrices)
        )

        let expectedValueFallback = PackPricing.basePrice(
            setID: "sv1", index: index, prices: cardPrices, marketPrices: nil)
        XCTAssertNotEqual(expectedValueFallback,
                          MarketEconomy.tokens(usd: 5000, prices: cardPrices))
    }
}
