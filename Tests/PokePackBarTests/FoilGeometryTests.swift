import AppKit
import XCTest
@testable import PokePackBar

final class FoilGeometryTests: XCTestCase {
    func testEveryOriginalHasMatchingGeometry() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        try FoilGeometry.verify(index: index)
    }

    func testAnniversaryDoesNotFallBackToVintageCoordinates() throws {
        let modern = try XCTUnwrap(FoilGeometry.entries["cel30-1"]?.illustration)
        let vintage = try XCTUnwrap(FoilGeometry.entries["cel30c-1"]?.illustration)
        XCTAssertEqual(modern.minY, 91.0 / 920, accuracy: 0.003)
        XCTAssertEqual(modern.maxY, 434.0 / 920, accuracy: 0.003)
        XCTAssertNotEqual(modern, vintage)
    }

    func testLetterboxedImageAndMaskShareTheSameTransform() {
        let holder = CGSize(width: 240, height: 335)
        let fit = FoilGeometry.imageRect(image: CGSize(width: 600, height: 825), holder: holder)
        XCTAssertEqual(fit.minY, 2.5, accuracy: 0.001)
        XCTAssertEqual(fit.height, 330, accuracy: 0.001)
        // A mask sized to the holder would be 5pt too tall; this was reachable
        // with the real older scans, not an invented aspect-ratio fixture.
        XCTAssertNotEqual(fit.size, holder)
    }

    func testTrainerAndEnergyAreNotPokemonWindows() throws {
        let trainer = try XCTUnwrap(FoilGeometry.entries["bw1-100"]?.illustration)
        XCTAssertLessThan(trainer.minY, 0.18)
        XCTAssertGreaterThan(trainer.minY, 0.14)
        XCTAssertNil(FoilGeometry.entries["base1-100"]?.illustration)
        XCTAssertNil(FoilGeometry.entries["cel30c-19"]?.illustration)
    }

    func testOldSecretCardsRetainTheirIllustrationWindows() {
        for id in ["bw1-115", "ecard2-148", "dp7-101", "cel30c-2", "cel30c-24", "cel30c-29"] {
            XCTAssertNotNil(FoilGeometry.entries[id]?.illustration, id)
        }
    }

    func testEReaderCurveExcludesThePrintedYellowCorner() throws {
        let path = try XCTUnwrap(FoilGeometry.illustrationPath(cardID: "ecard1-1", in: CGSize(width: 1, height: 1)))
        XCTAssertFalse(path.contains(CGPoint(x: 0.10, y: 0.13)))
        XCTAssertTrue(path.contains(CGPoint(x: 0.50, y: 0.30)))
    }

    @MainActor
    func testSegmentationCacheIdentityIncludesImageAndCrop() {
        let thumbnail = NSImage(size: NSSize(width: 180, height: 252))
        let original = NSImage(size: NSSize(width: 660, height: 920))
        let art = CGRect(x: 0.08, y: 0.10, width: 0.84, height: 0.37)
        let a = ArtworkMaskCache.key(cardID: "cel30-1", source: thumbnail, art: art)
        let b = ArtworkMaskCache.key(cardID: "cel30-1", source: original, art: art)
        let c = ArtworkMaskCache.key(cardID: "cel30-1", source: original, art: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(b, c)
    }

    func testAllMegaAttackLetteringUsesOriginalInkContours() {
        for number in 265...271 {
            let id = "me2pt5-\(number)"
            let path = FoilGeometry.letteringPath(cardID: id, in: CGSize(width: 1, height: 1))
            XCTAssertFalse(path.isEmpty, id)
            XCTAssertGreaterThan(path.boundingRect.width, 0.65, id)
            XCTAssertLessThan(path.boundingRect.minY, 0.4, id)
        }
    }
}
