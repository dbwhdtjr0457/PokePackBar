import XCTest
@testable import PokePackBar

@MainActor
final class LocalReliabilityTests: XCTestCase {
    /// 보조 에너지 원본 그림은 앱에 넣지 않는 감사 입력이다. 빌드 스크립트처럼 저장소의
    /// 원본 폴더를 넘겨 준다 — 넘기지 않으면 그림이 없다며 감사가 멈춘다.
    func testReleaseAuditAlsoRunsUnderXCTest() throws {
        let art = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PokePackBar/Resources/supplement-energy")
        let key = "PPB_SUPPLEMENT_ART_DIR"
        let previous = ProcessInfo.processInfo.environment[key]
        setenv(key, art.path, 1)
        defer {
            if let previous { setenv(key, previous, 1) } else { unsetenv(key) }
        }
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
