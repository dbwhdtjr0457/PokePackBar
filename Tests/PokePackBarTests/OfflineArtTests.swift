import AppKit
import XCTest
@testable import PokePackBar

@MainActor
final class OfflineArtTests: XCTestCase {
    func testThumbnailCannotSatisfyDetailRequest() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 245,
            pixelsHigh: 342, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertTrue(CardArtLibrary.accepts(data, hires: false))
        XCTAssertFalse(CardArtLibrary.accepts(data, hires: true))
        XCTAssertFalse(CardArtLibrary.isHighResolution(try XCTUnwrap(NSImage(data: data))))
        XCTAssertFalse(CardArtLibrary.accepts(Data("200 OK but not an image".utf8), hires: false))
    }

    func testLatestCatalogueAndAnniversarySlot() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        XCTAssertEqual(index.set("cel30")?.cardCount, 191)
        XCTAssertEqual(index.cards.filter { $0.setID == "me2pt5" && $0.tier == .megaAttack }.count, 7)
        XCTAssertTrue(try XCTUnwrap(index.card("me2pt5-57")).visualKind?.isTera == true)
        XCTAssertTrue(try XCTUnwrap(index.card("me2pt5-277")).visualKind?.isTera == true)
        XCTAssertFalse(try XCTUnwrap(index.card("me2pt5-276")).visualKind?.isTera == true)
        XCTAssertNil(index.set("me6"), "Unreleased sets must not enter the store")
        var rng = PackSeedGenerator(seed: 20260923)
        var pity = 0
        for _ in 0..<1_000 {
            let pack = PackOpening.draw(setID: "cel30", index: index, alreadyOwned: [],
                pity: &pity, mode: .realistic, using: &rng)
            XCTAssertEqual(pack.cards.count, 5)
            XCTAssertEqual(pack.cards.filter { index.card($0.id)?.rarity == "Pikachu Rare" }.count, 1)
            XCTAssertTrue(pack.cards.allSatisfy { $0.finish != .normal })
            XCTAssertFalse(pack.variant.isGodPack)
        }
    }
}
