import XCTest
@testable import PokePackBar

@MainActor
final class ExpansionFoilTests: XCTestCase {
    func testExpansionCoverageAndReachableParallels() throws {
        try ExpansionFoil.verify(index: XCTUnwrap(CardIndex.loadBundled()))
    }

    func testExistingCollectionIdentityDoesNotChangeWithTheMaterial() throws {
        let key = CardPrintingKey(storageKey: "cel30c-2#celebrationsClassic")
        XCTAssertEqual(key.storageKey, "cel30c-2#celebrationsClassic")
        let thirty = try XCTUnwrap(ExpansionFoil.spec(cardID: key.cardID, finish: key.finish))
        XCTAssertEqual(thirty.border, .gold)
        XCTAssertEqual(thirty.treatment, .classic30)
        XCTAssertNil(ExpansionFoil.spec(cardID: "cel25c-4", finish: .celebrationsClassic))
        XCTAssertNil(ExpansionFoil.spec(cardID: "cel30c-2", finish: .normal))
    }

    func testEachAscendedCardHasItsSpecificSymbolNotAnArbitraryBall() {
        XCTAssertEqual(ExpansionFoil.parallels["me2pt5-16"]?.pattern, .friendBall)
        XCTAssertEqual(ExpansionFoil.parallels["me2pt5-18"]?.pattern, .teamRocket)
        XCTAssertEqual(ExpansionFoil.parallels["me2pt5-1"]?.pattern, .pokeBall)
        XCTAssertNil(ExpansionFoil.parallels["me2pt5-181"], "Trainer cannot acquire a ball printing")
    }

    func testLegacyFoilSpecDecodesWithoutAnOpticalTreatment() throws {
        let data = Data(#"{"coverage":"fullCard","pattern":"confetti","texture":"none","border":"silver","intensity":0.62}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(FoilSpec.self, from: data).treatment)
    }

    func testFutureAndRGBDoNotShareTheSameSurface() throws {
        let fur = try XCTUnwrap(ExpansionFoil.spec(cardID: "cel30-157", finish: .etched))
        let rgb = try XCTUnwrap(ExpansionFoil.spec(cardID: "cel30-R_RGB", finish: .etched))
        XCTAssertNotEqual(fur.treatment, rgb.treatment)
        XCTAssertEqual(fur.border, .silver)
        XCTAssertEqual(rgb.border, .silver)
    }
}
