import Foundation
import SwiftUI

/// Card/printing-specific observations. The masks register to the installed
/// original; procedural optical reconstruction is not a factory emboss plate.
enum ReviewedFoilProfiles {
    enum Material: String, Decodable, Sendable {
        case silverFragments, goldFragments, confetti, radialFans, microEtching, goldStars, spectralStars
    }

    struct Layer: Decodable, Sendable {
        let name: String
        let material: Material
        let include: [[[Double]]]
        let exclude: [[[Double]]]
        let strength: Double
    }

    struct Fan: Decodable, Sendable {
        let x: Double
        let y: Double
        /// Radius is relative to card WIDTH, so the rings stay circular.
        let radius: Double
        let phase: Double
    }

    struct Entry: Decodable, Sendable {
        let cardID: String
        let finish: CardFinish
        let sha256: String
        let width: Int
        let height: Int
        let referenceURLs: [String]
        let evidenceStatus: String
        let reconstruction: String
        let physicalPlateVerified: Bool
        let baseInclude: [[[Double]]]
        let baseExclude: [[[Double]]]
        let layers: [Layer]
        let fans: [Fan]
    }

    private struct Manifest: Decodable {
        let version: Int
        let printings: [String: Entry]
        let starSheetExclusions: [String: StampExclusion]
    }

    struct StampExclusion: Decodable {
        let sha256: String
        let contours: [[[Double]]]
    }

    static let starSheetExclusions: [String: StampExclusion] = {
        guard let url = AppResources.bundle?.url(forResource: "reviewed-foil", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1 else { return [:] }
        return manifest.starSheetExclusions.filter { id, entry in
            entry.sha256 == CardArtLibrary.entries[id]?.sha256 && !entry.contours.isEmpty
                && entry.contours.allSatisfy { $0.count >= 3 && $0.allSatisfy {
                    $0.count == 2 && $0.allSatisfy { $0.isFinite && (0...1).contains($0) }
                } }
        }
    }()

    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "reviewed-foil", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.version == 1 else { return [:] }
        return manifest.printings.filter { key, entry in
            guard key == "\(entry.cardID)#\(entry.finish.rawValue)",
                  let art = CardArtLibrary.entries[entry.cardID] else { return false }
            return accepts(entry, hash: art.sha256, width: art.width, height: art.height)
        }
    }()

    static func entry(cardID: String, finish: CardFinish) -> Entry? {
        entries["\(cardID)#\(finish.rawValue)"]
    }

    static func accepts(_ entry: Entry, hash: String, width: Int, height: Int) -> Bool {
        guard entry.sha256 == hash, entry.width == width, entry.height == height,
              !entry.referenceURLs.isEmpty, !entry.layers.isEmpty,
              !entry.physicalPlateVerified, !entry.reconstruction.isEmpty else { return false }
        func validContours(_ contours: [[[Double]]]) -> Bool {
            contours.allSatisfy { contour in
                contour.count >= 3 && contour.allSatisfy { point in
                    point.count == 2 && point.allSatisfy { $0.isFinite && (0...1).contains($0) }
                }
            }
        }
        return validContours(entry.baseInclude + entry.baseExclude) && entry.layers.allSatisfy { layer in
            !layer.include.isEmpty && layer.strength.isFinite && (0...1).contains(layer.strength)
                && validContours(layer.include + layer.exclude)
        } && entry.fans.allSatisfy { fan in
            [fan.x, fan.y, fan.radius, fan.phase].allSatisfy(\.isFinite)
                && (0...1).contains(fan.x) && (0...1).contains(fan.y)
                && (0.08...0.55).contains(fan.radius)
        }
    }

    static func path(_ contours: [[[Double]]], size: CGSize) -> Path {
        var result = Path()
        for contour in contours {
            for (index, p) in contour.enumerated() {
                let point = CGPoint(x: p[0] * size.width, y: p[1] * size.height)
                if index == 0 { result.move(to: point) } else { result.addLine(to: point) }
            }
            result.closeSubpath()
        }
        return result
    }
}
