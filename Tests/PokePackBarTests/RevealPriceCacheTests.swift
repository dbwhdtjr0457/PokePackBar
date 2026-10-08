import XCTest
@testable import PokePackBar

@MainActor
final class RevealPriceCacheTests: XCTestCase {
    func testNewPriceSnapshotRecomputesTheSetsChaseThreshold() throws {
        let index = try XCTUnwrap(CardIndex.shared)
        let target = "base1-1"
        let card = PulledCard(id: target, tier: .common, isNew: false, finish: .normal)
        func prices(_ otherPrice: Double) throws -> CardPrices {
            var values = Dictionary(uniqueKeysWithValues:
                index.cards(inSet: "base1").map { ($0, otherPrice) })
            // 간판 카드 바닥(chaseFloorUSD 12달러)보다 높고 premium(40달러)보다 낮은 값.
            values[target] = 20
            let data = try JSONSerialization.data(withJSONObject: [
                "asOf": "2026-10-07", "currency": "USD", "krwPerUsd": 1368.52,
                "prices": values, "printingPrices": [:]
            ])
            return try XCTUnwrap(CardPrices.decode(data))
        }
        // 나머지가 더 비싸면 시세만큼(rare), 나머지가 싸지면 그 세트의 간판이 되어 premium.
        XCTAssertEqual(RevealValueEmphasis.emphasis(for: card, prices: try prices(25)), .rare)
        XCTAssertEqual(RevealValueEmphasis.emphasis(for: card, prices: try prices(1)), .premium)
    }
}
