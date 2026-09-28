import XCTest
import SwiftUI
@testable import PokePackBar

final class FoilSubjectMasksTests: XCTestCase {
    func testEveryConfirmedSubjectPrintingHasSourceBoundGeometry() throws {
        try FoilSubjectMasks.verify()
        XCTAssertEqual(FoilSubjectMasks.entries.count, 38)
    }

    func testNeoBordersArePaperAndDeltaRimsDoNotCoverTheTextPanel() {
        let size = CGSize(width: 240, height: 335)
        for id in FoilSubjectMasks.requiredCardIDs {
            let border = FoilSubjectMasks.borderPath(cardID: id, in: size)
            if id.hasPrefix("neo4-") { XCTAssertTrue(border.isEmpty, id) }
            else {
                XCTAssertFalse(border.isEmpty, id)
                XCTAssertFalse(border.contains(CGPoint(x: 120, y: 230), eoFill: true), id)
            }
        }
    }

    func testSourceReplacementInvalidatesReviewedMask() throws {
        let entry = try XCTUnwrap(FoilSubjectMasks.entries["neo4-107"])
        XCTAssertTrue(FoilSubjectMasks.accepts(entry, sourceHash: entry.sha256,
            width: entry.width, height: entry.height))
        XCTAssertFalse(FoilSubjectMasks.accepts(entry, sourceHash: "changed",
            width: entry.width, height: entry.height))
        XCTAssertFalse(FoilSubjectMasks.accepts(entry, sourceHash: entry.sha256,
            width: entry.width + 1, height: entry.height))
    }

    func testReprintsDoNotInheritOriginalSubjectMasks() {
        for id in ["cel30c-14", "cel25c-107", "sm35-40", "ex13-1", "ex14-1"] {
            XCTAssertFalse(FoilSubjectMasks.requiresRegisteredMask(cardID: id), id)
            XCTAssertNil(FoilSubjectMasks.subjectPath(cardID: id, in: CGSize(width: 1, height: 1)), id)
        }
    }

    func testKnownBackgroundAndPokemonSamplesUseDifferentMaskValues() throws {
        let samples: [(String, CGPoint, CGPoint)] = [
            ("neo4-107", CGPoint(x: 0.57, y: 0.285), CGPoint(x: 0.18, y: 0.45)),
            ("ex11-9", CGPoint(x: 0.62, y: 0.34), CGPoint(x: 0.28, y: 0.22)),
            ("ex15-9", CGPoint(x: 0.49, y: 0.30), CGPoint(x: 0.18, y: 0.15)),
        ]
        for (id, subject, background) in samples {
            let path = try XCTUnwrap(FoilSubjectMasks.subjectPath(cardID: id, in: CGSize(width: 1, height: 1)))
            XCTAssertTrue(path.contains(subject, eoFill: true), id)
            XCTAssertFalse(path.contains(background, eoFill: true), id)
        }
    }

    func testFullArtPikachuRetainsRoundedPaperCorners() throws {
        let size = CGSize(width: 719, height: 1000)
        let rect = try XCTUnwrap(FoilGeometry.illustration(cardID: "cel25-5", in: size))
        let path = try XCTUnwrap(FoilGeometry.illustrationPath(cardID: "cel25-5", in: size))
        XCTAssertFalse(path.contains(CGPoint(x: rect.minX + 1, y: rect.minY + 1)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
    }
}
