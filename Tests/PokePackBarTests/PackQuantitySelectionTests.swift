import XCTest
@testable import PokePackBar

final class PackQuantitySelectionTests: XCTestCase {
    func testAcceptsPositiveWholeNumberWithinNaturalMaximum() {
        XCTAssertEqual(PackQuantitySelection.validated(" 37 ", maximum: 250), 37)
        XCTAssertEqual(PackQuantitySelection.validated("250", maximum: 250), 250)
    }

    func testRejectsInvalidOrUnavailableQuantity() {
        XCTAssertNil(PackQuantitySelection.validated("", maximum: 250))
        XCTAssertNil(PackQuantitySelection.validated("0", maximum: 250))
        XCTAssertNil(PackQuantitySelection.validated("-1", maximum: 250))
        XCTAssertNil(PackQuantitySelection.validated("1.5", maximum: 250))
        XCTAssertNil(PackQuantitySelection.validated("251", maximum: 250))
        XCTAssertNil(PackQuantitySelection.validated("1", maximum: 0))
    }
}
