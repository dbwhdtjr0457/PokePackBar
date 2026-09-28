import XCTest
@testable import PokePackBar

final class RadiantCollectionRecipeTests: XCTestCase {
    private func bundledIndex() throws -> CardIndex {
        try XCTUnwrap(CardIndex.loadBundled(), "번들 카드 인덱스가 없다")
    }

    func testEnglishRadiantCollectionRecipesHaveTwoGuaranteedSheetPositions() {
        let expected: [PackRecipeSlot] = [
            PackRecipeSlot(kind: .common, count: 4),
            PackRecipeSlot(kind: .uncommon, count: 2),
            PackRecipeSlot(kind: .reverseHolo, count: 1),
            PackRecipeSlot(kind: .radiantCollectionCommon, count: 1),
            PackRecipeSlot(kind: .radiantCollectionHigh, count: 1),
            PackRecipeSlot(kind: .rare, count: 1),
        ]
        XCTAssertEqual(PackRecipe.forSet("g1", era: .blackWhite).slots, expected)

        var legendaryTreasures = expected
        legendaryTreasures[2] = PackRecipeSlot(kind: .legendaryTreasuresReverse, count: 1)
        XCTAssertEqual(PackRecipe.forSet("bw11", era: .blackWhite).slots,
                       legendaryTreasures)

        for setID in ["g1", "bw11"] {
            let contents = PackRecipe.forSet(setID, era: .blackWhite).contents
            XCTAssertEqual(contents.gameCardCount, 10, setID)
            XCTAssertEqual(contents.codeCardCount, 1, setID)
        }
    }

    func testRadiantSheetChecklistsCoverEveryRCNumberExactlyOnce() throws {
        let index = try bundledIndex()
        let generations = Set(PackRecipe.generationsRadiantCommonIDs
            + PackRecipe.generationsRadiantUncommonIDs
            + PackRecipe.generationsRadiantUltraIDs)
        let treasures = Set(PackRecipe.legendaryTreasuresRadiantCommonIDs
            + PackRecipe.legendaryTreasuresRadiantUncommonIDs
            + PackRecipe.legendaryTreasuresRadiantUltraIDs)

        XCTAssertEqual(generations.count, 32)
        XCTAssertEqual(treasures.count, 25)
        XCTAssertEqual(generations, Set(index.cards.filter {
            $0.id.hasPrefix("g1-RC")
        }.map(\.id)))
        XCTAssertEqual(treasures, Set(index.cards.filter {
            $0.id.hasPrefix("bw11-RC")
        }.map(\.id)))
    }

    func testEveryPackHasOneCardFromEachRCSheetAndNoLeakage() throws {
        let index = try bundledIndex()
        for (setID, commonIDs, highIDs) in [
            ("g1", Set(PackRecipe.generationsRadiantCommonIDs),
             Set(PackRecipe.generationsRadiantUncommonIDs
                + PackRecipe.generationsRadiantUltraIDs)),
            ("bw11", Set(PackRecipe.legendaryTreasuresRadiantCommonIDs),
             Set(PackRecipe.legendaryTreasuresRadiantUncommonIDs
                + PackRecipe.legendaryTreasuresRadiantUltraIDs)),
        ] {
            var generator = SeededGenerator(seed: 0xACED)
            var pity = 0
            for _ in 0..<1_000 {
                let opened = PackOpening.draw(setID: setID, index: index,
                                              alreadyOwned: [], pity: &pity,
                                              using: &generator)
                XCTAssertEqual(opened.cards.count, 10, setID)
                let rcCards = opened.cards.filter { $0.id.hasPrefix("\(setID)-RC") }
                XCTAssertEqual(rcCards.count, 2, setID)
                XCTAssertEqual(rcCards.filter { commonIDs.contains($0.id) }.count, 1, setID)
                XCTAssertEqual(rcCards.filter { highIDs.contains($0.id) }.count, 1, setID)
            }
        }
    }

    func testRadiantCollectionFinishesFollowTheEnglishPrintings() throws {
        let index = try bundledIndex()
        var generator = SeededGenerator(seed: 0xF011)
        var pity = 0

        for setID in ["g1", "bw11"] {
            for _ in 0..<200 {
                let opened = PackOpening.draw(setID: setID, index: index,
                                              alreadyOwned: [], pity: &pity,
                                              using: &generator)
                let common = try XCTUnwrap(opened.cards.first {
                    PackRecipe.radiantCollectionIDs(
                        setID: setID, slot: .radiantCollectionCommon, tier: $0.tier
                    ).contains($0.id)
                })
                let high = try XCTUnwrap(opened.cards.first {
                    $0.id.hasPrefix("\(setID)-RC") && $0.id != common.id
                })

                XCTAssertEqual(common.finish,
                               setID == "g1" ? .normal : .radiantCollection,
                               "\(setID) \(common.id)")
                XCTAssertEqual(high.finish, .radiantCollection, "\(setID) \(high.id)")
            }
        }
    }

    func testLegendaryTreasuresReverseOrHoloPositionUsesOnlyBaseHolos() throws {
        let index = try bundledIndex()
        let holoIDs = Set(PackRecipe.legendaryTreasuresHoloIDs)
        var generator = SeededGenerator(seed: 0xB11)
        var pity = 0
        var holoCount = 0
        let samples = 4_000

        for _ in 0..<samples {
            let opened = PackOpening.draw(setID: "bw11", index: index,
                                          alreadyOwned: [], pity: &pity,
                                          using: &generator)
            let reverseOrHolo = opened.cards[6]
            if reverseOrHolo.finish == .holo {
                holoCount += 1
                XCTAssertTrue(holoIDs.contains(reverseOrHolo.id), reverseOrHolo.id)
            } else {
                XCTAssertEqual(reverseOrHolo.finish, .reverseHolo, reverseOrHolo.id)
                XCTAssertFalse(holoIDs.contains(reverseOrHolo.id), reverseOrHolo.id)
            }

            let rareSlot = opened.cards[9]
            if rareSlot.tier == .doubleRare {
                XCTAssertFalse(holoIDs.contains(rareSlot.id), rareSlot.id)
            }
        }

        XCTAssertEqual(Double(holoCount) / Double(samples), 0.50, accuracy: 0.03)
    }

    func testSeparatelyNumberedSubsetsOnlyUseTheirReplacementPosition() throws {
        let index = try bundledIndex()
        let cases = [
            ("sm115", "sma-"), ("swsh45", "swsh45sv-"),
            ("swsh9", "swsh9tg-"), ("swsh10", "swsh10tg-"),
            ("swsh11", "swsh11tg-"), ("swsh12", "swsh12tg-"),
            ("swsh12pt5", "swsh12pt5gg-"),
        ]

        for (setID, prefix) in cases {
            var generator = SeededGenerator(seed: 0x515E7)
            for _ in 0..<300 {
                let cards = PackOpening.draw(setID: setID, index: index,
                                             alreadyOwned: [], using: &generator)
                for (offset, card) in cards.enumerated() where card.id.hasPrefix(prefix) {
                    XCTAssertEqual(offset, 8, "\(setID): \(card.id) leaked into slot \(offset)")
                }
            }
        }

        var celebrationsGenerator = SeededGenerator(seed: 0xCE125)
        for _ in 0..<300 {
            let cards = PackOpening.draw(setID: "cel25", index: index,
                                         alreadyOwned: [], using: &celebrationsGenerator)
            for (offset, card) in cards.enumerated() where card.id.hasPrefix("cel25c-") {
                XCTAssertEqual(offset, 2, "\(card.id) leaked into slot \(offset)")
            }
        }
    }
}
