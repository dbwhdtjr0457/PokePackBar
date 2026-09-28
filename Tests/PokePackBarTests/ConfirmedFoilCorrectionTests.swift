import XCTest
@testable import PokePackBar

final class ConfirmedFoilCorrectionTests: XCTestCase {
    private func resolve(_ id: String, finish: CardFinish? = nil) throws -> ResolvedCardFinish {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let card = try XCTUnwrap(index.card(id))
        return CardFinishResolver.resolve(cardID: id, setID: card.setID,
            originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind,
            explicitFinish: finish)
    }

    func testGoldMewCorrectsBothNewAndPreviouslySavedHoloOpticsWithoutChangingKeys() throws {
        for finish in [nil, CardFinish.holo] {
            let result = try resolve("cel25-25", finish: finish)
            XCTAssertEqual(result.finish, .holo)
            XCTAssertEqual(result.spec.pattern, .swordShieldGold)
            XCTAssertEqual(result.spec.coverage, .fullCard)
            XCTAssertEqual(result.spec.border, .gold)
            XCTAssertEqual(FoilReliefMaterial(pattern: result.spec.pattern), .gold(.swordShieldGold))
        }
        XCTAssertEqual(try resolve("cel25-11").spec.pattern, .celebrationSheen)
        XCTAssertEqual(try resolve("cel25-25", finish: .normal).spec.coverage, .none)
    }

    func testFullArtPikachuMaskReachesFeetWithoutFoilingPaperFrame() throws {
        let art = try XCTUnwrap(FoilGeometry.entries["cel25-5"]?.illustration)
        XCTAssertLessThan(art.minY, 0.04)
        XCTAssertGreaterThan(art.maxY, 0.96)
        XCTAssertGreaterThan(art.minX, 0.03)
        XCTAssertLessThan(art.maxX, 0.97)
        let result = try resolve("cel25-5")
        XCTAssertEqual(result.spec.coverage, .artWindow)
        XCTAssertEqual(result.spec.texture, .none)
        XCTAssertEqual(result.spec.border, .paper)
    }

    func testNeoShiningAndDeltaDoNotReflectTheEntireBackground() throws {
        for number in 106...113 {
            let result = try resolve("neo4-\(number)")
            XCTAssertEqual(result.spec.coverage, .artSubject)
            XCTAssertEqual(result.spec.border, .paper)
        }
        for (set, count) in [("ex11", 18), ("ex15", 12)] {
            for number in 1...count {
                XCTAssertEqual(try resolve("\(set)-\(number)").spec.coverage, .artSubjectAndBorder)
            }
        }
        XCTAssertEqual(try resolve("cel30c-14").spec.treatment, .classic30)
    }

    func testAuditIncludesLegendaryTreasuresReverseButNotRadiantCollectionOrHoloSlot() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let core = index.cards.filter { $0.id.hasPrefix("bw11-") && !$0.id.hasPrefix("bw11-RC") }
        let reversed = core.filter {
            FoilAuditPrintings.finishes(for: $0, index: index).contains(.reverseHolo)
        }
        XCTAssertEqual(reversed.count, 71)
        for card in index.cards.filter({ $0.id.hasPrefix("bw11-RC") }) {
            XCTAssertFalse(FoilAuditPrintings.finishes(for: card, index: index).contains(.reverseHolo))
        }
    }

    func testAuditBallParallelEligibilityMatchesOpeningForEveryCard() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for card in index.cards {
            let finishes = FoilAuditPrintings.finishes(for: card, index: index)
            for (finish, masterOnly) in [(CardFinish.pokeBall, false), (.masterBall, true)] {
                let expected = !PackOpening.prismaticParallelCandidates(setID: card.setID,
                    pool: [card.tier: [card.id]], masterBallOnly: masterOnly).isEmpty
                XCTAssertEqual(finishes.contains(finish), expected, card.id)
            }
        }
    }
}
