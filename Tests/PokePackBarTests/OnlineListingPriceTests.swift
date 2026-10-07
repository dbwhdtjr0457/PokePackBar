import XCTest
@testable import PokePackBar

@MainActor
final class OnlineListingPriceTests: XCTestCase {
    func testMarketPriceConversionRejectsOverflowAndServerLimit() throws {
        XCTAssertNil(OnlineText.tokens(won: Int.max))
        XCTAssertNil(OnlineText.tokens(won: -100))
        XCTAssertNil(OnlineText.tokens(won: 99))
        XCTAssertEqual(OnlineText.tokens(won: 100), MarketEconomy.stepTokens())
        let maximum = OnlineText.maximumListingWon
        XCTAssertLessThanOrEqual(try XCTUnwrap(OnlineText.tokens(won: maximum)),
                                 OnlineText.maximumListingTokens)
        XCTAssertNil(OnlineText.tokens(won: maximum + 100))
    }
}
