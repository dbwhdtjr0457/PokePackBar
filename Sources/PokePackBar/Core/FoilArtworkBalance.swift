import Foundation

/// Source-bound visual tuning. Unknown or replaced images keep the original
/// sheet response; low-signal printings are never globally dimmed.
enum FoilArtworkBalance {
    struct Entry: Decodable {
        let sha256: String
        let coatingGain: Double
        let dormantFleckOpacity: Double
    }
    private struct Manifest: Decodable {
        let version: Int
        let cards: [String: Entry]
    }
    static let entries: [String: Entry] = {
        guard let url = AppResources.bundle?.url(forResource: "foil-artwork-balance", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.version == 1
        else { return [:] }
        return manifest.cards.filter { id, entry in
            entry.sha256 == CardArtLibrary.entries[id]?.sha256
                && entry.coatingGain.isFinite && (0.2...1).contains(entry.coatingGain)
                && entry.dormantFleckOpacity.isFinite && (0...0.88).contains(entry.dormantFleckOpacity)
        }
    }()
}
