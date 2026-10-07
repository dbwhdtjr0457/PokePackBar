import XCTest
@testable import PokePackBar

final class SupplementalEnergyFoilTests: XCTestCase {
    func testAnniversaryEnergyUsesFullCardFoilWithoutScanTexture() {
        for type in SupplementalEnergyCard.EnergyType.allCases where type != .fairy {
            let resolved = CardFinishResolver.resolve(
                cardID: "supplement-energy-mee30-\(type.rawValue)",
                setID: "supplement", originalRarity: nil, tier: .energy, explicitFinish: .holo)
            XCTAssertEqual(resolved.spec.coverage, .fullCard)
            XCTAssertEqual(resolved.spec.pattern, .mirage)
            XCTAssertEqual(resolved.spec.texture, .none)
        }
    }
}
