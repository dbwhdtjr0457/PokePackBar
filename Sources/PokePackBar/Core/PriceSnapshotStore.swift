import Foundation
import CoreFoundation

/// Explicit snapshot application, never a background price mutation. All consumers
/// use the same immutable pair, and a notification invalidates the visible UI.
final class PriceSnapshotStore: @unchecked Sendable {
    static let shared = PriceSnapshotStore()
    static let changed = Notification.Name("PokePackBar.priceSnapshotChanged")
    struct Snapshot: Sendable { let cards: CardPrices; let packs: PackMarketPrices }
    private let lock = NSLock()
    private var snapshot: Snapshot?
    let url: URL
    private let bundledCards = CardPrices.loadBundled()
    private let bundledPacks = PackMarketPrices.loadBundled()
    var cards: CardPrices? { lock.withLock { snapshot?.cards ?? bundledCards } }
    var packs: PackMarketPrices? { lock.withLock { snapshot?.packs ?? bundledPacks } }
    var usesImportedSnapshot: Bool { lock.withLock { snapshot != nil } }

    init(url: URL? = nil) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokePackBar")
        self.url = url ?? dir.appendingPathComponent("price-snapshot.json")
        if let data = try? Self.read(self.url) { snapshot = try? Self.validate(data) }
    }

    static func read(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 25_000_000 else { throw SnapshotError.invalid }
        return try Data(contentsOf: url)
    }

    enum SnapshotError: LocalizedError {
        case invalid
        var errorDescription: String? { "Invalid price snapshot. Expected schemaVersion 1, USD cardPrices and packPrices; previous prices were kept." }
    }

    static func validate(_ data: Data) throws -> Snapshot {
        guard data.count <= 25_000_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["schemaVersion"] as? Int == 1,
              let cardsObject = object["cardPrices"] as? [String: Any],
              let packsObject = object["packPrices"] as? [String: Any],
              let representatives = cardsObject["prices"] as? [String: Any],
              let printings = cardsObject["printingPrices"] as? [String: Any],
              representatives.values.allSatisfy(validPrice),
              printings.values.allSatisfy(validPrice),
              printings.keys.allSatisfy({ key in
                  let parts = key.split(separator: "#", omittingEmptySubsequences: false)
                  return parts.count == 2 && !parts[0].isEmpty && CardFinish(rawValue: String(parts[1])) != nil
              }),
              let cards = CardPrices.decode(try JSONSerialization.data(withJSONObject: cardsObject, options: [.sortedKeys])),
              let packs = PackMarketPrices.decode(try JSONSerialization.data(withJSONObject: packsObject, options: [.sortedKeys]))
        else { throw SnapshotError.invalid }
        // An accidentally partial export must not reprice most of the collection to fallback values.
        if let bundled = CardPrices.loadBundled(), let index = CardIndex.shared {
            guard index.cards.allSatisfy({ card in
                (bundled.price(card.id) == nil || cards.price(card.id) != nil) &&
                CardFinish.allCases.allSatisfy { finish in
                    bundled.exactPrice(cardID: card.id, finish: finish) == nil || cards.exactPrice(cardID: card.id, finish: finish) != nil
                }
            })
            else { throw SnapshotError.invalid }
        }
        if let bundled = PackMarketPrices.loadBundled(), let index = CardIndex.shared {
            guard index.sets.allSatisfy({ bundled.entry(setID: $0.id) == nil || packs.entry(setID: $0.id) != nil })
            else { throw SnapshotError.invalid }
        }
        return Snapshot(cards: cards, packs: packs)
    }

    private static func validPrice(_ value: Any) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return number.doubleValue.isFinite && number.doubleValue >= 0 && number.doubleValue < 10_000_000
    }

    func apply(_ data: Data) throws {
        let candidate = try Self.validate(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        lock.withLock { snapshot = candidate }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    func reset() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
            try FileManager.default.removeItem(at: url)
        }
        lock.withLock { snapshot = nil }
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }
}
