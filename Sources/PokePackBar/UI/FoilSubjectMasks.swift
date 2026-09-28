import Foundation
import SwiftUI

/// Reviewed source-art silhouettes, not factory foil/emboss plates. Restrict
/// reflective subjects without asking a foreground model on every card hover.
enum FoilSubjectMasks {
    struct Entry: Decodable, Sendable {
        let sha256: String
        let width: Int
        let height: Int
        let method: String
        let physicalPlateVerified: Bool
        let subject: [[[Double]]]
        let border: [[[Double]]]
        let subjectArtFraction: Double
    }
    private struct Manifest: Decodable { let version: Int; let cards: [String: Entry] }

    static let requiredCardIDs = Set((106...113).map { "neo4-\($0)" }
        + (1...18).map { "ex11-\($0)" } + (1...12).map { "ex15-\($0)" })

    static func requiresRegisteredMask(cardID: String) -> Bool { requiredCardIDs.contains(cardID) }

    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "foil-subject-masks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1 else { return [:] }
        return manifest.cards.filter { cardID, entry in
            guard requiredCardIDs.contains(cardID), let original = CardArtLibrary.entries[cardID] else { return false }
            return accepts(entry, sourceHash: original.sha256, width: original.width, height: original.height)
        }
    }()

    static func accepts(_ entry: Entry, sourceHash: String, width: Int, height: Int) -> Bool {
        guard entry.sha256 == sourceHash, entry.width == width, entry.height == height,
              !entry.subject.isEmpty, entry.subjectArtFraction.isFinite,
              (0.05...0.90).contains(entry.subjectArtFraction) else { return false }
        return (entry.subject + entry.border).allSatisfy { contour in
            contour.count >= 3 && contour.allSatisfy { point in
                point.count == 2 && point.allSatisfy { $0.isFinite && (0...1).contains($0) }
            }
        }
    }

    static func subjectPath(cardID: String, in size: CGSize) -> Path? {
        guard let entry = entries[cardID] else { return nil }
        return path(entry.subject, in: size)
    }

    static func borderPath(cardID: String, in size: CGSize) -> Path {
        path(entries[cardID]?.border ?? [], in: size)
    }

    private static func path(_ contours: [[[Double]]], in size: CGSize) -> Path {
        var result = Path()
        for contour in contours {
            for (index, point) in contour.enumerated() {
                let location = CGPoint(x: point[0] * size.width, y: point[1] * size.height)
                if index == 0 { result.move(to: location) } else { result.addLine(to: location) }
            }
            result.closeSubpath()
        }
        return result
    }

    static func verify() throws {
        try LocalAudit.require(Set(entries.keys) == requiredCardIDs, "Missing/stale reviewed subject masks")
        let size = CGSize(width: 1, height: 1)
        for id in requiredCardIDs {
            guard let entry = entries[id], let subject = subjectPath(cardID: id, in: size),
                  let art = FoilGeometry.illustration(cardID: id, in: size) else {
                throw LocalAudit.Failure(description: "Missing source illustration for reviewed subject mask: \(id)")
            }
            try LocalAudit.require(!accepts(entry, sourceHash: "changed", width: entry.width, height: entry.height),
                                   "Changed original retained its reviewed subject mask: \(id)")
            try LocalAudit.require(!subject.isEmpty && !entry.physicalPlateVerified, "Invalid subject-mask provenance: \(id)")
            try LocalAudit.require(art.insetBy(dx: -0.003, dy: -0.003).contains(subject.boundingRect),
                                   "Subject mask escaped its source illustration: \(id)")
            try LocalAudit.require(!subject.contains(CGPoint(x: 0.5, y: 0.8), eoFill: true),
                                   "Subject mask covers attack text: \(id)")
            if id.hasPrefix("neo4-") {
                try LocalAudit.require(entry.border.isEmpty, "Neo Shining acquired a foil paper border: \(id)")
            } else {
                let border = borderPath(cardID: id, in: size)
                try LocalAudit.require(!border.isEmpty && !border.contains(CGPoint(x: 0.5, y: 0.7), eoFill: true),
                                       "Delta metal rim covers the text panel: \(id)")
            }
        }
        let samples: [(String, CGPoint, CGPoint)] = [
            ("neo4-107", CGPoint(x: 0.57, y: 0.285), CGPoint(x: 0.18, y: 0.45)),
            ("ex11-9", CGPoint(x: 0.62, y: 0.34), CGPoint(x: 0.28, y: 0.22)),
            ("ex15-9", CGPoint(x: 0.49, y: 0.30), CGPoint(x: 0.18, y: 0.15)),
        ]
        for (id, pokemon, background) in samples {
            guard let subject = subjectPath(cardID: id, in: size) else {
                throw LocalAudit.Failure(description: "Missing landmark subject: \(id)")
            }
            try LocalAudit.require(subject.contains(pokemon, eoFill: true)
                && !subject.contains(background, eoFill: true), "Subject/background mask landmarks were swapped: \(id)")
        }
    }
}
