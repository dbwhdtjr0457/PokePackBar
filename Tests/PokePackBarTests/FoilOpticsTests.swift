import XCTest
@testable import PokePackBar

final class FoilOpticsTests: XCTestCase {
    @MainActor
    func testProductionDispatchPalettesAndBadInputMutations() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        try FoilOpticsAudit.verify(index: index)
    }

    func testOpposingAxesDoNotAverageToPerpendicularScratches() {
        let angle = FoilReliefMaterial.blendRidgeDirection(0, .pi, weight: 0.4)
        XCTAssertLessThan(abs(sin(angle)), 0.000001)
    }
}
