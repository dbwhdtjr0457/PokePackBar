import Foundation
import CryptoKit

enum OpeningMode: String, Codable, CaseIterable, Sendable {
    case game, realistic
}

/// SplitMix64, versioned together with the draw rules. No live wallet is needed.
struct PackSeedGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum OpeningRules {
    static let version = "english-2026-09-23-v4-splitmix64-swift6"
    static let historyLimit = 1_000
    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static let catalogueDigest: String = {
        guard let url = AppResources.bundle?.url(forResource: "card-index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return "unavailable" }
        return digest(data)
    }()
}

struct PackSupplement: Codable, Equatable, Sendable {
    let energyCount: Int
    let holoEnergy: Bool
    let codeCount: Int

    static func contents(setID: String, era: PackEra, variant: PackVariant) -> Self {
        let counts = PackRecipe.forSet(setID, era: era).contents
        return Self(energyCount: counts.energyCardCount,
                    holoEnergy: variant == .blackBoltWhiteFlareGod,
                    codeCount: counts.codeCardCount)
    }
}

struct OpeningRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let openedAt: Date
    let setID: String
    let seed: String
    let rulesVersion: String
    let catalogueDigest: String
    let mode: OpeningMode
    let hitOddsBonus: Double
    let pityBefore: Int
    let pityAfter: Int
    let variant: PackVariant
    let printings: [CardPrintingKey]
    let supplement: PackSupplement
    let cardPriceDate: String?
    let printingPriceDate: String?
    let priceSnapshotDigest: String?
    let packQuote: PackPriceQuote
}
