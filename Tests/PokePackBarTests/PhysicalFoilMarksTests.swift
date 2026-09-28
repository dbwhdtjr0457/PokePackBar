import XCTest
import SwiftUI
@testable import PokePackBar

@MainActor
final class PhysicalFoilMarksTests: XCTestCase {
    func testTracedMotifsAndSourceBoundRegistrationsAreAvailable() throws {
        XCTAssertEqual(PhysicalFoilMarks.templates.count, 16)
        XCTAssertEqual(PhysicalFoilMarks.registrations.count, 280)
        for (key, entry) in PhysicalFoilMarks.registrations {
            let id = String(key.split(separator: "#")[0])
            XCTAssertEqual(entry.sha256, CardArtLibrary.entries[id]?.sha256, key)
            XCTAssertGreaterThanOrEqual(entry.inliers, 14, key)
            XCTAssertTrue(entry.referenceURL.hasPrefix("https://tcgplayer-cdn.tcgplayer.com/product/")
                || entry.referenceURL.hasPrefix("https://static.wixstatic.com/media/"), key)
            XCTAssertEqual(entry.referenceSHA256.count, 64, key)
            let path = try XCTUnwrap(PhysicalFoilMarks.ascendedPath(cardID: id,
                ball: key.hasSuffix("#patternedReverse"), in: CGSize(width: 240, height: 335)), key)
            XCTAssertGreaterThan(path.boundingRect.width, 80, key)
            XCTAssertLessThan(path.boundingRect.width, 145, key)
            XCTAssertGreaterThan(path.boundingRect.minY, 155, key)
            XCTAssertLessThan(path.boundingRect.maxY, 288, key)
        }
    }

    func testUnavailableReferencesDoNotUseInventedFallbacks() {
        for id in ["me2pt5-181"] {
            for ball in [false, true] {
                XCTAssertNil(PhysicalFoilMarks.ascendedPath(cardID: id, ball: ball, in: CGSize(width: 240, height: 335)))
            }
        }
    }

    func testAlternateReferencesRestoreEveryMissingPrinting() {
        for number in [66, 69, 71, 72] {
            for finish in ["reverseHolo", "patternedReverse"] {
                let entry = PhysicalFoilMarks.registrations["me2pt5-\(number)#\(finish)"]
                XCTAssertEqual(entry?.registration, "own-printing")
                XCTAssertTrue(entry?.referenceURL.hasPrefix("https://static.wixstatic.com/media/") == true)
            }
        }
    }

    func testMarksScaleWithTheRenderedSourceNotTheHolder() throws {
        let small = try XCTUnwrap(PhysicalFoilMarks.ascendedPath(cardID: "me2pt5-16", ball: true,
            in: CGSize(width: 240, height: 335))).boundingRect
        let large = try XCTUnwrap(PhysicalFoilMarks.ascendedPath(cardID: "me2pt5-16", ball: true,
            in: CGSize(width: 480, height: 670))).boundingRect
        XCTAssertEqual(large.minX, small.minX * 2, accuracy: 0.001)
        XCTAssertEqual(large.minY, small.minY * 2, accuracy: 0.001)
        XCTAssertEqual(large.width, small.width * 2, accuracy: 0.001)
        XCTAssertEqual(large.height, small.height * 2, accuracy: 0.001)
    }

    func testEXUsesAuthenticBundledWordmarksAndRarityColors() throws {
        XCTAssertEqual(PhysicalFoilMarks.logos.count, 10)
        for n in 7...16 {
            XCTAssertNotNil(PhysicalFoilMarks.logoImage(setID: "ex\(n)"))
        }
        XCTAssertNil(PhysicalFoilMarks.logoImage(setID: "ex6"))
        XCTAssertTrue(PhysicalFoilMarks.usesColoredEXLogo(setID: "ex9", rarity: "Rare Holo"))
        XCTAssertFalse(PhysicalFoilMarks.usesColoredEXLogo(setID: "ex9", rarity: "Common"))
        XCTAssertFalse(PhysicalFoilMarks.usesColoredEXLogo(setID: "ex11", rarity: "Rare Holo"))
    }

    func testNativeResourcesAndActualSilverPixels() throws {
        try PhysicalFoilMarks.verify()
    }
}
