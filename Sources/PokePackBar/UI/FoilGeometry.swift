import AppKit
import SwiftUI

/// Coordinates belong to a particular oriented scan, not a set, rarity or
/// outer card holder. The resource is generated from original image landmarks.
enum FoilGeometry {
    struct Entry: Decodable, Sendable {
        let sha256: String
        let width: Int
        let height: Int
        let art: [Double]?
        let profile: String
        let confidence: Double
        let method: String
        let outline: [[Double]]
        let lettering: [[[Double]]]
        let accents: [[[Double]]]

        var illustration: CGRect? {
            guard let art, art.count == 4 else { return nil }
            return CGRect(x: art[0], y: art[1], width: art[2] - art[0], height: art[3] - art[1])
        }
    }
    private struct Manifest: Decodable { let version: Int; let cards: [String: Entry] }

    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "foil-geometry", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1 else { return [:] }
        return manifest.cards.filter { id, entry in
            guard let original = CardArtLibrary.entries[id], original.sha256 == entry.sha256,
                  entry.width == min(original.width, original.height),
                  entry.height == max(original.width, original.height) else { return false }
            guard (entry.outline + (entry.lettering + entry.accents).flatMap { $0 }).allSatisfy({ point in
                point.count == 2 && point.allSatisfy { $0.isFinite && (0...1).contains($0) }
            }) else { return false }
            guard let a = entry.art else { return true }
            return a.count == 4 && a.allSatisfy(\.isFinite)
                && a[0] >= 0 && a[1] >= 0 && a[2] <= 1 && a[3] <= 1 && a[0] < a[2] && a[1] < a[3]
        }
    }()

    static func illustration(cardID: String, in size: CGSize) -> CGRect? {
        guard let rect = entries[cardID]?.illustration else { return nil }
        return rect.applying(CGAffineTransform(scaleX: size.width, y: size.height))
    }

    static func artRect(cardID: String, in size: CGSize) -> CGRect {
        illustration(cardID: cardID, in: size) ?? CGRect(origin: .zero, size: size)
    }

    static func illustrationPath(cardID: String, in size: CGSize) -> Path? {
        guard let entry = entries[cardID], let rect = illustration(cardID: cardID, in: size) else { return nil }
        if entry.profile == "full-art-paper-frame" {
            // The rounded interior is part of the source scan, not the holder.
            // Keep Celebrations Pikachu's printed yellow corner wedges matte.
            return Path(roundedRect: rect, cornerRadius: size.width * 16 / Double(entry.width))
        }
        guard entry.outline.count >= 3 else { return Path(rect) }
        return contourPath([entry.outline], in: size)
    }

    static func letteringPath(cardID: String, in size: CGSize) -> Path {
        contourPath(entries[cardID]?.lettering ?? [], in: size)
    }

    static func nameAccentPath(cardID: String, in size: CGSize) -> Path {
        contourPath(entries[cardID]?.accents ?? [], in: size)
    }

    /// Reverse-only stamps are not in the regular source scan. Keep this
    /// approximation in the measured lower panel, with one shared anchor for
    /// both the stamp and its coverage mask (never two independent constants).
    static func parallelMarkRect(cardID: String, in size: CGSize) -> CGRect {
        let art = artRect(cardID: cardID, in: size)
        let centerY = art.maxY + max(0, size.height * 0.90 - art.maxY) * 0.38
        return CGRect(x: size.width * 0.37, y: centerY - size.height * 0.055,
                      width: size.width * 0.26, height: size.height * 0.11)
    }

    private static func contourPath(_ contours: [[[Double]]], in size: CGSize) -> Path {
        var path = Path()
        for contour in contours where contour.count >= 3 {
            for (index, point) in contour.enumerated() where point.count == 2 {
                let location = CGPoint(x: point[0] * size.width, y: point[1] * size.height)
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            path.closeSubpath()
        }
        return path
    }

    /// Same aspect-fit transform as CardImageView. Used by executable geometry
    /// tests to guard letterboxed scans; masks themselves live INSIDE the image.
    static func imageRect(image: CGSize, holder: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let scale = min(holder.width / image.width, holder.height / image.height)
        let fit = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (holder.width - fit.width) / 2, y: (holder.height - fit.height) / 2,
                      width: fit.width, height: fit.height)
    }

    static func verify(index: CardIndex) throws {
        try LocalAudit.require(Set(entries.keys) == Set(index.cards.map(\.id)), "Incomplete or stale foil geometry")
        for card in index.cards {
            guard let entry = entries[card.id] else { continue }
            for width: CGFloat in [180, 240, 420] {
                let size = CGSize(width: width, height: (width / 0.717).rounded())
                let image = CGSize(width: entry.width, height: entry.height)
                let fit = imageRect(image: image, holder: size)
                try LocalAudit.require(fit.minX >= -0.001 && fit.minY >= -0.001
                    && fit.maxX <= size.width + 0.001 && fit.maxY <= size.height + 0.001,
                    "Image extends beyond holder: \(card.id)")
                if let rect = illustration(cardID: card.id, in: fit.size) {
                    try LocalAudit.require(CGRect(origin: .zero, size: fit.size).contains(rect), "Foil outside image: \(card.id)")
                }
            }
        }
        try LocalAudit.require(entries["cel30-1"]?.illustration?.minY ?? 1 < 0.11, "30th uses vintage fallback")
        try LocalAudit.require(entries["bw1-100"]?.illustration?.minY ?? 1 < 0.18, "Trainer illustration starts too low")
        try LocalAudit.require(entries["base1-100"]?.illustration == nil, "Energy contains a fake illustration hole")
        let letterboxed = imageRect(image: CGSize(width: 600, height: 825), holder: CGSize(width: 240, height: 335))
        try LocalAudit.require(abs(letterboxed.minY - 2.5) < 0.001 && abs(letterboxed.height - 330) < 0.001,
                               "Mask stretched across the outer holder")
        for id in ["bw1-115", "ecard2-148", "dp7-101", "cel30c-2", "cel30c-6", "cel30c-24", "cel30c-29"] {
            try LocalAudit.require(entries[id]?.illustration != nil, "Framed secret/reprint treated as full art: \(id)")
        }
        for number in 265...271 {
            let path = letteringPath(cardID: "me2pt5-\(number)", in: CGSize(width: 1, height: 1))
            try LocalAudit.require(!path.isEmpty && path.boundingRect.width > 0.65
                && path.boundingRect.minY < 0.4, "Missing original MA lettering: \(number)")
        }
        let curved = illustrationPath(cardID: "ecard1-1", in: CGSize(width: 1, height: 1))
        try LocalAudit.require(curved?.contains(CGPoint(x: 0.10, y: 0.13)) == false
            && curved?.contains(CGPoint(x: 0.50, y: 0.30)) == true, "E-reader curve was flattened")
        try LocalAudit.require(entries["cel25c-9_A"]?.profile == "ex"
            && entries["cel25c-15_A3"]?.profile == "vintage", "Classic duplicate-number frames confused")
        try LocalAudit.require(!nameAccentPath(cardID: "ex7-1", in: CGSize(width: 1, height: 1)).isEmpty,
                               "EX header ink contours missing")
    }
}
