import SwiftUI

/// Fixed photograph-space regions, not a second random triangulation.
enum RegisteredCrackedIce {
    struct Facet: Decodable { let points: [[Double]]; let regions: [[[Double]]]; let phase: Double }
    struct Entry: Decodable {
        let sha256: String
        let width: Int
        let height: Int
        let sourceURL: String
        let coverage: String
        let art: [Double]
        let physicalNormalsVerified: Bool
        let facets: [Facet]
    }
    private struct Manifest: Decodable { let version: Int; let cards: [String: Entry] }
    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "cracked-ice-facets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1 else { return [:] }
        return manifest.cards.filter { id, entry in
            guard let original = CardArtLibrary.entries[id], entry.sha256 == original.sha256,
                  entry.width == original.width, entry.height == original.height,
                  !entry.physicalNormalsVerified, entry.art.count == 4, entry.facets.count >= 12 else { return false }
            return entry.facets.allSatisfy { facet in
                facet.phase.isFinite && facet.points.count >= 3 && !facet.regions.isEmpty
                && facet.regions.allSatisfy { $0.count >= 3 } && facet.regions.flatMap { $0 }.allSatisfy {
                    $0.count == 2 && $0.allSatisfy { $0.isFinite && (0...1).contains($0) }
                }
            }
        }
    }()

    static func response(phase: Double, tilt: TiltVector) -> Double {
        0.12 + 0.88 * pow(max(0, cos(phase + tilt.nx * 3.2 - tilt.ny * 2.7)), 3)
    }

    @MainActor static func verify() throws {
        let expected = Set(["ex5-97","ex5-98","ex5-99","ex6-114","ex6-115","ex6-116"]
            + (1...6).map { "pl2-RT\($0)" })
        try LocalAudit.require(Set(entries.keys) == expected, "Source-bound cracked facets missing")
        for (id, entry) in entries {
            try LocalAudit.require(entry.coverage == (id.hasPrefix("pl2-") ? "outsideArt" : "fullCard"),
                "Rotom shards moved into the artwork: \(id)")
            try LocalAudit.require(entry.facets.contains { abs(response(phase: $0.phase, tilt: TiltVector(nx: 0, ny: 0))
                - response(phase: $0.phase, tilt: TiltVector(nx: 0.6, ny: -0.4))) > 0.5 },
                "Static cracked facets: \(id)")
        }
    }
}

@MainActor
struct RegisteredCrackedIceLayer: View {
    let entry: RegisteredCrackedIce.Entry
    let tilt: TiltVector

    var body: some View {
        Canvas { context, size in
            let a = entry.art
            let art = CGRect(x: a[0]*size.width, y: a[1]*size.height,
                width: (a[2]-a[0])*size.width, height: (a[3]-a[1])*size.height)
            if entry.coverage == "outsideArt" {
                var region = Path(CGRect(x: 0.026*size.width,y: 0.015*size.height,
                    width: 0.947*size.width,height: 0.968*size.height))
                region.addRect(art)
                context.clip(to: region, style: FillStyle(eoFill: true))
            }
            for facet in entry.facets {
                let path = ReviewedFoilProfiles.path(facet.regions, size: size)
                let response = RegisteredCrackedIce.response(phase: facet.phase, tilt: tilt)
                context.fill(path, with: .color(.black.opacity((1-response)*0.76)), style: FillStyle(eoFill: true))
                let hue = (facet.phase / (.pi*2) + tilt.nx*0.20 - tilt.ny*0.16 + 2)
                    .truncatingRemainder(dividingBy: 1)
                var reflection = context
                reflection.blendMode = .screen
                reflection.fill(path, with: .color(Color(hue: hue, saturation: 0.55, brightness: 1)
                    .opacity(0.03 + response*0.88)), style: FillStyle(eoFill: true))
            }
        }
    }
}
