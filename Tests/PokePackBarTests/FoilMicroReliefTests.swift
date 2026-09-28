import AppKit
import SwiftUI
import XCTest
@testable import PokePackBar

@MainActor
final class FoilMicroReliefTests: XCTestCase {
    func testAllAffectedCataloguePrintingsReachTheirEtchedFamily() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        var counts: [FoilMicroRelief: Int] = [:]
        for card in index.cards {
            let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind)
            guard let family = FoilMicroRelief(pattern: resolved.spec.pattern) else { continue }
            counts[family, default: 0] += 1
            XCTAssertEqual(FoilReliefMaterial(pattern: resolved.spec.pattern,
                                             texture: resolved.spec.texture),
                           .microEtched(family), card.id)
            XCTAssertEqual(resolved.spec.coverage, .fullCard, card.id)
            // The relief renderer owns the fine geometry. A second coarse
            // texture layer must not be required to rescue a missing material.
            XCTAssertEqual(resolved.spec.texture, .none, card.id)
        }
        XCTAssertEqual(counts, [.vstar: 43, .shinyGX: 35, .shinyV: 9,
                                .shinyVMAX: 7, .shinyEx: 10, .teraShinyEx: 2])
    }

    func testOnlyTheSixConfirmedPatternsGainThisRelief() {
        let patterns: [FoilPattern] = [.vstarSheen, .shinyGX, .shinyV,
                                      .shinyVMAX, .shinyEx, .teraShinyEx]
        XCTAssertEqual(Set(patterns.compactMap(FoilMicroRelief.init)), Set(FoilMicroRelief.allCases))
        for pattern in [FoilPattern.doubleRareSheen, .teraSheen, .cosmos, .celebrationSheen] {
            XCTAssertNil(FoilMicroRelief(pattern: pattern), pattern.rawValue)
        }
    }

    func testReliefRemainsMicroscopicAndFamiliesCannotShareCacheEntries() {
        let materials = FoilMicroRelief.allCases.map(FoilReliefMaterial.microEtched)
        XCTAssertEqual(Set(materials.map(\.cacheKey)).count, 6)
        for material in materials {
            let longestRidgeAt240Points = 240 / Double(material.columns) * (material.facetLength + 0.34)
            XCTAssertLessThan(longestRidgeAt240Points, 2, material.cacheKey)
            XCTAssertGreaterThan(material.shadowStrength, 0.25, material.cacheKey)
        }
        let directions = FoilMicroRelief.allCases.map {
            $0.geometry(x: 0.37, y: 0.46, phase: 1.2).direction
        }
        XCTAssertEqual(Set(directions).count, 6)
    }

    /// This is a missing-render/contrast regression guard, not physical-card
    /// visual approval. Native card previews still need an eye-level review.
    func testEachReliefHasBrightAndDarkAngleResponseAt240Points() throws {
        for family in FoilMicroRelief.allCases {
            let rest = try render(family, tilt: .zero, background: .gray)
            let tilted = try render(family, tilt: TiltVector(nx: 0.72, ny: -0.62), background: .gray)
            let white = try render(family, tilt: TiltVector(nx: 0.72, ny: -0.62), background: .white)
            let plain = try render(nil, tilt: .zero, background: .gray)
            let plainWhite = try render(nil, tilt: .zero, background: .white)
            var brighter = 0
            var darker = 0
            var changed = 0
            var whiteShadow = 0
            var restDeviation = 0
            var tiltDeviation = 0
            for pixel in 0..<(rest.count / 4) {
                let i = pixel * 4
                let value = Int(tilted[i]) + Int(tilted[i + 1]) + Int(tilted[i + 2])
                let base = Int(plain[i]) + Int(plain[i + 1]) + Int(plain[i + 2])
                restDeviation += abs(Int(rest[i]) + Int(rest[i + 1]) + Int(rest[i + 2]) - base)
                tiltDeviation += abs(value - base)
                if value > base + 12 { brighter += 1 }
                if value < base - 12 { darker += 1 }
                if abs(Int(rest[i]) - Int(tilted[i]))
                    + abs(Int(rest[i + 1]) - Int(tilted[i + 1]))
                    + abs(Int(rest[i + 2]) - Int(tilted[i + 2])) > 24 { changed += 1 }
                if Int(white[i]) + Int(white[i + 1]) + Int(white[i + 2])
                    < Int(plainWhite[i]) + Int(plainWhite[i + 1]) + Int(plainWhite[i + 2]) - 18 {
                    whiteShadow += 1
                }
            }
            let pixelCount = Double(rest.count / 4)
            XCTAssertGreaterThan(Double(brighter) / pixelCount, 0.01, family.rawValue)
            XCTAssertGreaterThan(Double(darker) / pixelCount, 0.01, family.rawValue)
            XCTAssertGreaterThan(Double(changed) / pixelCount, 0.03, family.rawValue)
            XCTAssertGreaterThan(Double(whiteShadow) / pixelCount, 0.01, family.rawValue)
            XCTAssertGreaterThan(Double(tiltDeviation), Double(restDeviation) * 1.5,
                                 "Face-on relief must not resemble static dark grain: \(family.rawValue)")
        }
    }

    private func render(_ family: FoilMicroRelief?, tilt: TiltVector, background: Color) throws -> [UInt8] {
        let view = ZStack {
            background
            if let family {
                FoilReliefLayer(material: .microEtched(family), seed: 573,
                                tilt: tilt)
            }
        }.frame(width: 240, height: 335)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(rendered)
        return pixels
    }
}
