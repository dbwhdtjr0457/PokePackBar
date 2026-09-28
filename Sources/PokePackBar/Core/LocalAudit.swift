import AppKit
import Foundation

/// Release-binary checks work even on a Mac with CommandLineTools but no XCTest.
/// This entry point runs before WalletStore/default paths or application startup.
@MainActor
enum LocalAudit {
    struct Failure: Error, CustomStringConvertible { let description: String }
    nonisolated static func require(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
        if try !condition() { throw Failure(description: label) }
    }

    static func run(_ args: [String]) throws -> Bool {
        guard args.contains("--audit-local") || args.contains("--export-printing-map") || args.contains("--export-foil-map")
                || args.contains("--simulate-packs") || args.contains("--replay-openings")
                || args.contains("--audit-image-library") || args.contains("--audit-foil-geometry")
                || args.contains("--audit-confirmed-foil-fixes") || args.contains("--audit-price-snapshot")
                || args.contains("--audit-korean-names") || args.contains("--audit-foil-optics")
                || args.contains("--audit-reviewed-foil") else { return false }
        guard let index = CardIndex.shared else { throw Failure(description: "Missing card index") }
        if args.contains("--audit-reviewed-foil") {
            try ReviewedFoilAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-foil-optics") {
            try FoilOpticsAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-korean-names") {
            try KoreanNameAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-price-snapshot") {
            try PriceSnapshotAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-confirmed-foil-fixes") {
            try ConfirmedFoilAudit.verify(index: index)
            return true
        }
        if args.contains("--audit-foil-geometry") {
            try FoilGeometry.verify(index: index)
            try ExpansionFoil.verify(index: index)
            try FoilSubjectMasks.verify()
            try PhysicalFoilMarks.verify()
            let first = NSImage(size: NSSize(width: 660, height: 920))
            let replacement = NSImage(size: NSSize(width: 660, height: 920))
            let art = CGRect(x: 0.08, y: 0.10, width: 0.84, height: 0.37)
            try require(ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: art)
                != ArtworkMaskCache.key(cardID: "cel30-1", source: replacement, art: art),
                "Replacement original reused old segmentation")
            try require(ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: art)
                != ArtworkMaskCache.key(cardID: "cel30-1", source: first, art: .zero),
                "Changed illustration crop reused old segmentation")
            print("PASS foil geometry: \(index.cards.count) original hashes/layouts at 180/240/420pt; wallet untouched")
            return true
        }
        if args.contains("--audit-image-library") {
            let count = try CardArtLibrary.verify(index: index, hashes: true)
            // Exercise the real loader against small/preloaded and corrupt
            // input, not just the on-disk filenames or CDN size parameters.
            try require(!CardArtLibrary.accepts(Data("not an image".utf8), hires: true), "Corrupt image accepted")
            for id in ["base1-4", "me2-130", "me2pt5-295", "cel30-158", "cel30c-1", "cel30c-9", "cel30c-19"] {
                guard let data = CardArtLibrary.data(id),
                      let small = CardArtLibrary.image(data, hires: false),
                      let large = CardImageLoader.cachedImage(cardID: id, hires: true)
                else { throw Failure(description: "Offline loader failed: \(id)") }
                try require(!CardArtLibrary.isHighResolution(small), "Grid image was not downsampled")
                try require(CardArtLibrary.isHighResolution(large), "Detail retained thumbnail: \(id)")
                try require(large.size.width < large.size.height, "Landscape scan was cropped or stretched: \(id)")
            }
            print("PASS offline image library: \(count) decoded dimensions + SHA-256; real grid/detail loader; wallet untouched")
            return true
        }
        if args.contains("--export-foil-map") {
            struct Sample: Encodable {
                let cardID: String
                let finish: CardFinish
                let spec: FoilSpec
                let opticalMaterial: String?
            }
            var samples: [String: Sample] = [:]
            for card in index.cards {
                for finish in FoilAuditPrintings.finishes(for: card, index: index) {
                    let resolved = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                        originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind, explicitFinish: finish)
                    guard resolved.spec.isFoil else { continue }
                    let s = resolved.spec
                    let key = args.contains("--all-cards") ? "\(card.id)#\(resolved.finish.rawValue)" : "\(resolved.finish.rawValue)/\(s.coverage.rawValue)/\(s.pattern.rawValue)/\(s.texture.rawValue)/\(s.border.rawValue)/\(s.intensity)/\(s.treatment?.rawValue ?? "legacy")"
                    if samples[key] == nil {
                        samples[key] = Sample(cardID: card.id, finish: resolved.finish, spec: s,
                            opticalMaterial: ReviewedFoilProfiles.entry(cardID: card.id, finish: resolved.finish)
                                .map { "reviewed-" + $0.layers.map(\.material.rawValue).joined(separator: "+") }
                                ?? FoilSheetMaterial(pattern: s.pattern, cardID: card.id).map { "sheet-\($0.rawValue)" }
                                ?? FoilOpticsAudit.material(card.id, s)?.cacheKey)
                    }
                }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            print(String(decoding: try encoder.encode(samples), as: UTF8.self))
            return true
        }
        if args.contains("--export-printing-map") {
            let map = Dictionary(uniqueKeysWithValues: index.cards.map { card in
                (card.id, CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                    originalRarity: card.rarity, tier: card.tier, visualKind: card.visualKind).finish.rawValue)
            })
            print(String(decoding: try JSONEncoder().encode(map), as: UTF8.self))
            return true
        }
        if let at = args.firstIndex(of: "--replay-openings") {
            guard args.count > at + 1 else { throw Failure(description: "Expected history JSON path") }
            let data = try Data(contentsOf: URL(fileURLWithPath: args[at + 1]))
            let records = try JSONDecoder().decode([OpeningRecord].self, from: data)
            for record in records {
                try require(record.rulesVersion == OpeningRules.version && record.catalogueDigest == OpeningRules.catalogueDigest,
                            "Rules/catalogue mismatch: use the recorded app version, not current rules")
                guard let seed = UInt64(record.seed) else { throw Failure(description: "Invalid seed") }
                var generator = PackSeedGenerator(seed: seed)
                var pity = record.pityBefore
                let result = PackOpening.draw(setID: record.setID, index: index, alreadyOwned: [],
                    perks: DexPerks(hitOdds: record.hitOddsBonus), pity: &pity,
                    mode: record.mode, using: &generator)
                try require(result.variant == record.variant && pity == record.pityAfter &&
                    result.cards.map { CardPrintingKey(cardID: $0.id, finish: $0.finish) } == record.printings,
                    "Replay mismatch: \(record.id)")
            }
            print("PASS replay: \(records.count) openings; live wallet untouched")
            return true
        }
        if let at = args.firstIndex(of: "--simulate-packs") {
            guard args.count > at + 3, let count = Int(args[at + 2]), (1...1_000_000).contains(count),
                  let seed = UInt64(args[at + 3]), index.set(args[at + 1]) != nil
            else { throw Failure(description: "Usage: --simulate-packs SET COUNT(1...1000000) SEED [--game]") }
            try simulate(index: index, setID: args[at + 1], count: count, seed: seed,
                         mode: args.contains("--game") ? .game : .realistic)
            return true
        }
        try audit(index)
        return true
    }

    static func simulate(index: CardIndex, setID: String, count: Int, seed: UInt64, mode: OpeningMode) throws {
        var rng = PackSeedGenerator(seed: seed)
        var pity = 0
        var variants: [String: Int] = [:]
        var tiers: [String: Int] = [:]
        let prices = CardPrices.shared
        var valueSum = 0.0
        var valueSquares = 0.0
        let expected = PackRecipe.forSet(setID, era: index.era(setID)).contents.gameCardCount
        for _ in 0..<count {
            let result = PackOpening.draw(setID: setID, index: index, alreadyOwned: [],
                pity: &pity, mode: mode, using: &rng)
            try require(result.cards.count == expected, "Wrong card count: \(setID)")
            variants[result.variant.rawValue, default: 0] += 1
            for card in result.cards { tiers[card.tier.rawValue, default: 0] += 1 }
            let value = result.cards.reduce(0.0) { $0 + MarketEconomy.usd(cardID: $1.id, finish: $1.finish, prices: prices) }
            valueSum += value
            valueSquares += value * value
        }
        let mean = valueSum / Double(count)
        let standardError = sqrt(max(0, valueSquares / Double(count) - mean * mean) / Double(count))
        let result: [String: Any] = ["setID": setID, "packs": count, "seed": String(seed),
            "rulesVersion": OpeningRules.version, "mode": mode.rawValue, "variants": variants, "tiers": tiers,
            "sampleMeanUSD": mean, "sampleStandardErrorUSD": standardError,
            "noPityModelEVUSD": MarketEconomy.packValueUSD(setID: setID, index: index, prices: prices)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }

    static func audit(_ index: CardIndex) throws {
        if index.set("cel30") != nil {
            try require(index.cards.filter { $0.setID == "me2pt5" && $0.visualKind?.isTera == true }.count == 7,
                        "Ascended Heroes printed Tera labels were lost")
            var generator = PackSeedGenerator(seed: 20260923)
            var pity = 0
            var seen: Set<String> = []
            for _ in 0..<10_000 {
                let result = PackOpening.draw(setID: "cel30", index: index, alreadyOwned: [],
                    pity: &pity, mode: .realistic, using: &generator)
                try require(result.cards.count == 5 && !result.variant.isGodPack, "30th physical composition failed")
                try require(result.cards.filter { index.card($0.id)?.rarity == "Pikachu Rare" }.count == 1,
                            "30th must contain exactly one Pikachu Rare")
                try require(result.cards.allSatisfy { $0.finish != .normal }, "30th contains a non-foil printing")
                seen.formUnion(result.cards.map(\.id))
            }
            try require(index.cards.filter { $0.setID == "cel30" }.allSatisfy { seen.contains($0.id) },
                        "30th checklist has unreachable cards")
            let megaAttack = PackOpening.slotPool(setID: "me2pt5", slot: .reverseHoloHit,
                pool: index.pools["me2pt5"] ?? [:], index: index)[.megaAttack] ?? []
            try require(megaAttack.count == 7 && PackConfig.slotTables(setID: "me2pt5", era: .scarletViolet)
                .contains { $0.weights.contains { $0.tier == .megaAttack && $0.weight > 0 } }, "Mega Attack cannot be drawn")
            print("PASS latest catalogue: 10,000 anniversary packs, exact Pikachu slot, all foil, complete reachability, 7 Mega Attack cards")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-regression-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game-state.json")
        let persistence = GamePersistence(url: url)
        var initial = GameState()
        initial.usedSinceInstall = 9_000_000_000
        initial.packs = ["sv8pt5": 3]
        try persistence.commit(initial)
        var fails = false
        var commits = 0
        let wallet = WalletStore(fileURL: url, dexes: [], ladder: [], commitState: { state in
            commits += 1
            if fails { throw Failure(description: "Injected disk write failure") }
            try persistence.commit(state)
        })
        let before = wallet.availableTokens
        commits = 0
        try require(wallet.buyPacks(setID: "sv8pt5", count: 2, total: 1_000), "Purchase failed")
        try require(commits == 1 && wallet.availableTokens == before - 1_000 && wallet.packCount(setID: "sv8pt5") == 5, "Purchase is not one commit")
        fails = true
        try require(!wallet.buyPacks(setID: "sv8pt5", count: 2, total: 1_000), "Failed purchase reported success")
        try require(wallet.packCount(setID: "sv8pt5") == 5 && wallet.availableTokens == before - 1_000, "Purchase rollback failed")
        try require(wallet.openPack(setID: "sv8pt5", index: index, seed: 11) == nil, "Failed opening reported success")
        try require(wallet.packCount(setID: "sv8pt5") == 5 && wallet.state.cards.isEmpty && wallet.state.openingHistory.isEmpty,
                    "Opening rollback failed")
        try require(wallet.pullOripa(index: index, envelope: 0) == nil, "Failed Oripa reported success")
        try require(wallet.state.oripa == nil && wallet.state.cards.isEmpty && wallet.availableTokens == before - 1_000,
                    "Oripa rollback failed")
        fails = false
        commits = 0
        guard let opened = wallet.openPack(setID: "sv8pt5", index: index, seed: 11),
              let record = wallet.state.openingHistory.last else { throw Failure(description: "Opening failed") }
        try require(commits == 1 && opened.opened.cards.count == 10, "Opening is not one commit")
        var replay = PackSeedGenerator(seed: 11)
        var pity = record.pityBefore
        let result = PackOpening.draw(setID: record.setID, index: index, alreadyOwned: [], pity: &pity,
                                      mode: record.mode, using: &replay)
        try require(result.cards.map { CardPrintingKey(cardID: $0.id, finish: $0.finish) } == record.printings,
                    "Seed replay differs")
        let historyURL = directory.appendingPathComponent("history.json")
        try JSONEncoder().encode(wallet.state.openingHistory).write(to: historyURL)
        try require(try run(["--replay-openings", historyURL.path]), "History replay command failed")
        let bytes = try Data(contentsOf: url)
        for _ in 0..<12 { try persistence.commit(wallet.state) }
        try require(try persistence.backupURLs().count == GamePersistence.retainedBackups, "Backup rotation failed")
        try Data("invalid".utf8).write(to: url, options: .atomic)
        let restored = try persistence.load()
        try require(restored.recovered && restored.state.packs == wallet.state.packs, "Recovery failed")
        try require(try Data(contentsOf: url) == bytes, "Recovery altered save")
        print("PASS purchase/open atomic commit, injected failure rollback, seed replay, 8 backups, corruption recovery")

        let blockedDirectory = directory.appendingPathComponent("blocked")
        try FileManager.default.createDirectory(at: blockedDirectory, withIntermediateDirectories: true)
        let blockedURL = blockedDirectory.appendingPathComponent("game-state.json")
        let blockedPersistence = GamePersistence(url: blockedURL)
        try blockedPersistence.commit(initial)
        // A real filesystem failure, not just the injected closure: a regular
        // file prevents creating the backup directory, so the original remains.
        try Data("not a directory".utf8).write(to: blockedPersistence.backupDirectory)
        let blockedWallet = WalletStore(fileURL: blockedURL, dexes: [], ladder: [])
        try require(!blockedWallet.buyPacks(setID: "sv8pt5", count: 1, total: 1_000), "Disk failure reported success")
        try require(blockedWallet.availableTokens == initial.usedSinceInstall && blockedWallet.packCount(setID: "sv8pt5") == 3,
                    "Disk failure changed wallet")
        let corruptURL = directory.appendingPathComponent("unrecoverable/game-state.json")
        try FileManager.default.createDirectory(at: corruptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corruptData = Data("{\"cards\":false}".utf8)
        try corruptData.write(to: corruptURL)
        let corruptWallet = WalletStore(fileURL: corruptURL, dexes: [], ladder: [])
        try require(!corruptWallet.buyPacks(setID: "sv8pt5", count: 1, total: 1), "Unreadable save was writable")
        try require(try Data(contentsOf: corruptURL) == corruptData, "Unreadable original overwritten")
        var futureState = initial
        futureState.schemaVersion = 999
        let futureData = try JSONEncoder().encode(futureState)
        try futureData.write(to: url, options: .atomic)
        var refusedDowngrade = false
        do { _ = try persistence.load() }
        catch GamePersistence.Failure.newerVersion { refusedDowngrade = true }
        try require(refusedDowngrade && (try Data(contentsOf: url)) == futureData,
                    "Newer save was downgraded to an old backup")

        guard let cardURL = AppResources.bundle?.url(forResource: "card-prices", withExtension: "json"),
              let packURL = AppResources.bundle?.url(forResource: "pack-prices", withExtension: "json")
        else { throw Failure(description: "Missing price resources") }
        var envelope: [String: Any] = ["schemaVersion": 1,
            "cardPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: cardURL)),
            "packPrices": try JSONSerialization.jsonObject(with: Data(contentsOf: packURL))]
        let priceData = try JSONSerialization.data(withJSONObject: envelope)
        let localPrices = PriceSnapshotStore(url: directory.appendingPathComponent("prices.json"))
        try localPrices.apply(priceData)
        try require(localPrices.usesImportedSnapshot, "Snapshot was not applied")
        var partialCards = envelope["cardPrices"] as! [String: Any]
        partialCards["printingPrices"] = [:] as [String: Double]
        envelope["cardPrices"] = partialCards
        var rejected = false
        do { try localPrices.apply(JSONSerialization.data(withJSONObject: envelope)) }
        catch { rejected = true }
        try require(rejected && (try Data(contentsOf: localPrices.url)) == priceData, "Partial snapshot replaced prices")
        partialCards["printingPrices"] = ["sv8pt5-1#invented": 42]
        envelope["cardPrices"] = partialCards
        rejected = false
        do { _ = try PriceSnapshotStore.validate(JSONSerialization.data(withJSONObject: envelope)) }
        catch { rejected = true }
        try require(rejected, "Unknown printing was accepted")
        try localPrices.reset()
        try require(!localPrices.usesImportedSnapshot && FileManager.default.fileExists(atPath: localPrices.url.appendingPathExtension("previous").path),
                    "Snapshot reset lost recovery copy")
        print("PASS Oripa rollback, real disk failure, unrecoverable-save protection, snapshot import/rejection/reset")

        var rng = PackSeedGenerator(seed: 20260923)
        var samples = 0
        for set in index.sets {
            let recipe = PackRecipe.forSet(set.id, era: index.era(set.id))
            let odds = PackOpening.packOdds(setID: set.id, index: index)
            try require(abs(odds.reduce(0) { $0 + $1.probability } - 1) < 0.000001, "Odds sum: \(set.id)")
            for _ in 0..<200 {
                var pity = PackConfig.pityThreshold
                let pack = PackOpening.draw(setID: set.id, index: index, alreadyOwned: [],
                    perks: .caps, pity: &pity, mode: .realistic, using: &rng)
                try require(pity == 0 && pack.cards.count == recipe.contents.gameCardCount, "Realistic count/pity: \(set.id)")
                try require(pack.cards.allSatisfy { index.card($0.id)?.setID == set.id }, "Wrong-set card")
                if recipe.specialRules.isEmpty { try require(!pack.variant.isSpecialHit, "Impossible God Pack") }
                samples += 1
            }
        }
        var found: Set<PackVariant> = []
        for seed in 0..<100_000 {
            var rng = PackSeedGenerator(seed: UInt64(seed))
            var pity = 0
            let result = PackOpening.draw(setID: "sv8pt5", index: index, alreadyOwned: [],
                                          pity: &pity, mode: .realistic, using: &rng)
            if result.variant == .prismaticEvolutionsDemigod {
                try require(result.cards.filter { $0.tier == .specialArtRare }.count == 3, "Demi composition")
                found.insert(result.variant)
            }
            if result.variant == .prismaticEvolutionsGod {
                try require(result.cards.first?.finish == .masterBall && result.cards.count == 10, "God composition")
                found.insert(result.variant)
            }
            if found.count == 2 { break }
        }
        try require(found.count == 2, "Missing special variant")
        try require(!AppLinks.updatesConfigured, "Custom build allows upstream updates")
        print("PASS \(index.sets.count) sets / \(samples) realistic packs; both Prismatic variants; custom update protection")
    }
}
