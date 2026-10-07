import XCTest
@testable import PokePackBar

final class CollectionStatsRefreshTests: XCTestCase {
    func testTradeAndPackPurchaseRefreshStatsWithoutOpeningCards() {
        let initial = GameState()
        let original = CollectionStats.RefreshID(state: initial, prices: nil)
        var traded = initial
        traded.cards = ["base1-1": 1]
        traded.printingCards = ["base1-1#holo": 1]
        XCTAssertEqual(traded.packsOpened, initial.packsOpened)
        XCTAssertEqual(traded.cardsDisenchanted, initial.cardsDisenchanted)
        XCTAssertNotEqual(CollectionStats.RefreshID(state: traded, prices: nil), original)
        var purchased = initial
        purchased.spentTokens = 100
        XCTAssertNotEqual(CollectionStats.RefreshID(state: purchased, prices: nil), original)
    }
}
