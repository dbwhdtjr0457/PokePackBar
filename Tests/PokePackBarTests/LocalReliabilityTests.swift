import XCTest
@testable import PokePackBar

@MainActor
final class LocalReliabilityTests: XCTestCase {
    func testReleaseAuditAlsoRunsUnderXCTest() throws {
        try LocalAudit.audit(XCTUnwrap(CardIndex.shared))
    }

    func testShiningLegendsFoilsTheSubjectWithoutThePaperBorder() {
        let resolved = CardFinishResolver.resolve(cardID: "sm35-27", setID: "sm35",
            originalRarity: "Rare Shining", tier: .shining)
        XCTAssertEqual(resolved.spec.coverage, .artSubject)
        XCTAssertEqual(resolved.spec.texture, .sunMoonEtched)
        XCTAssertEqual(resolved.spec.border, .paper)
    }

    func testPrismaticHasBothMutuallyExclusiveSpecialRules() {
        let recipe = PackRecipe.forSet("sv8pt5", era: .scarletViolet)
        XCTAssertEqual(recipe.specialRules.map(\.variant), [.prismaticEvolutionsGod, .prismaticEvolutionsDemigod])
        XCTAssertEqual(recipe.standardShare(for: .rare), 1 - 2.0 / 2_500, accuracy: 0.000001)
    }

    func testBabyShinyPaperBordersAreOutsideTheFoilMask() {
        for (id, set) in [("sma-SV1", "sma"), ("swsh45sv-SV001", "swsh45sv")] {
            let resolved = CardFinishResolver.resolve(cardID: id, setID: set,
                originalRarity: "Rare Shiny", tier: .shiny)
            XCTAssertEqual(resolved.spec.coverage, .artWindow)
            XCTAssertEqual(resolved.spec.border, .paper)
        }
    }
}
