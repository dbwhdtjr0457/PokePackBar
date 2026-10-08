import Foundation
import XCTest
@testable import PokePackBar

/// 공개 연출은 등급 이름이 아니라 **그 팩에서 얼마나 드물게 나오는가**로 정한다.
final class RevealRarityTests: XCTestCase {

    /// 매 팩 나오는 등급에는 연출이 없다. 30주년 팩의 피카츄 레어가 매 팩 한 장 고정인데,
    /// 등급 이름(AR)으로 연출을 정하던 때는 매번 같은 축하가 터졌다.
    func testFrequentPullsGetNoEffect() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for set in index.sets {
            for tier in CardTier.allCases {
                guard let packs = PullRarity.packsPerPull(setID: set.id, tier: tier, index: index) else { continue }
                XCTAssertGreaterThanOrEqual(packs, 1 - 1e-9, "\(set.id) \(tier.rawValue): 한 팩에 확률이 1을 넘는다")
                if packs < PullRarity.Threshold.rare {
                    XCTAssertEqual(PullRarity.emphasis(packsPerPull: packs), .none,
                                   "\(set.id) \(tier.rawValue): \(packs)팩에 한 번인데 연출이 있다")
                }
            }
        }
        let pikachu = try XCTUnwrap(PullRarity.packsPerPull(setID: "cel30", tier: .artRare, index: index))
        XCTAssertLessThan(pikachu, PullRarity.Threshold.rare, "30주년 피카츄 레어는 매 팩 나온다")
    }

    /// 요즘 팩의 R 은 거의 매 팩 나온다. 파란 불꽃이 터지면 안 된다.
    func testModernRaresStayQuiet() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for setID in ["sv1", "sv10", "me1", "swsh1", "sm1"] {
            let packs = try XCTUnwrap(PullRarity.packsPerPull(setID: setID, tier: .rare, index: index))
            XCTAssertEqual(PullRarity.emphasis(packsPerPull: packs), .none, "\(setID) R: \(packs)팩에 한 번")
        }
    }

    /// 드물수록 단계가 오르고, 가장 높은 단계는 150팩에 한 번보다 드문 카드뿐이다.
    func testStepsClimbWithRarity() {
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 1), .none)
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 3.9), .none)
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 6), .rare)
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 20), .premium)
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 80), .apex)
        XCTAssertEqual(PullRarity.emphasis(packsPerPull: 400), .mythic)
        var last = RevealEmphasis.none
        for packs in stride(from: 1.0, through: 1_000, by: 0.5) {
            let step = PullRarity.emphasis(packsPerPull: packs)
            XCTAssertGreaterThanOrEqual(step, last, "\(packs)팩에서 단계가 내려갔다")
            last = step
        }
    }

    /// 시세는 연출을 올릴 수 있지만 가장 높은 단계(무지개)까지는 아니다. 그것은 드묾의 몫이다.
    @MainActor
    func testValueAloneNeverReachesTheTopStep() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        let priciest = try XCTUnwrap(index.cards.max {
            MarketEconomy.usd(cardID: $0.id, prices: prices) < MarketEconomy.usd(cardID: $1.id, prices: prices)
        })
        let card = PulledCard(id: priciest.id, tier: priciest.tier, isNew: false)
        XCTAssertLessThanOrEqual(RevealValueEmphasis.emphasis(for: card, prices: prices), .apex)
    }
}
