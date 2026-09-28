import XCTest
@testable import PokePackBar

@MainActor
final class KoreanNameAuditTests: XCTestCase {
    func testPackagedNamesAndMissingTranslationMutations() throws {
        try KoreanNameAudit.verify(index: XCTUnwrap(CardIndex.loadBundled()))
    }
}
