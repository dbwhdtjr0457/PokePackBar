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
            values[target] = 4
            let data = try JSONSerialization.data(withJSONObject: [
                "asOf": "2026-10-07", "currency": "USD", "krwPerUsd": 1368.52,
                "prices": values, "printingPrices": [:]
            ])
            return try XCTUnwrap(CardPrices.decode(data))
        }
        XCTAssertEqual(RevealValueEmphasis.emphasis(for: card, prices: try prices(5)), .none)
        XCTAssertEqual(RevealValueEmphasis.emphasis(for: card, prices: try prices(1)), .premium)
    }
}
