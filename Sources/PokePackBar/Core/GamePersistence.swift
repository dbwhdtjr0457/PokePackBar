import Foundation
import CoreFoundation

/// A commit has exactly one durable point: atomic replacement of game-state.json.
/// Backups contain the previous, decoded state, never the uncommitted candidate.
struct GamePersistence {
    let url: URL
    var backupDirectory: URL { url.deletingLastPathComponent().appendingPathComponent("save-backups") }
    static let retainedBackups = 8

    struct Loaded {
        let state: GameState
        let recovered: Bool
    }

    enum Failure: LocalizedError {
        case invalidSave, unrecoverable, newerVersion
        var errorDescription: String? {
            switch self {
            case .invalidSave: "Invalid game save. The original file was preserved."
            case .unrecoverable: "Cannot read the save or recover a valid backup. Saving is disabled to protect the original."
            case .newerVersion: "This save belongs to a newer app version. Saving and automatic recovery are disabled to protect it."
            }
        }
    }

    static func decode(_ data: Data) throws -> GameState {
        // The legacy decoder is deliberately lenient. At the persistence boundary,
        // reject malformed present ledger fields instead of blessing them as zero.
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["cards"] != nil || object["usedSinceInstall"] != nil else { throw Failure.invalidSave }
        if let version = object["schemaVersion"] as? Int, version > 2 { throw Failure.newerVersion }
        let counters = ["usedSinceInstall", "spentTokens", "refundedTokens", "perkTokens",
                        "cardsDisenchanted", "packsOpened"]
        let maps = ["cards", "printingCards", "packs", "cardFirstAt", "packPity",
                    "claimedTodayTokensByProvider", "packGrantTier"]
        func valid(_ value: Any) -> Bool {
            guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return false }
            let d = n.doubleValue
            return d.isFinite && d >= 0 && d <= Double(Int.max / 64) && d.rounded(.down) == d
        }
        for key in counters { if let value = object[key], !valid(value) { throw Failure.invalidSave } }
        for key in maps {
            guard let value = object[key], !(value is NSNull) else { continue }
            guard let map = value as? [String: Any], map.values.allSatisfy(valid) else { throw Failure.invalidSave }
        }
        return try JSONDecoder().decode(GameState.self, from: data)
    }

    func load() throws -> Loaded {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: url.path)
        if exists, let data = try? Data(contentsOf: url) {
            do { return Loaded(state: try Self.decode(data), recovered: false) }
            catch Failure.newerVersion { throw Failure.newerVersion }
            catch { /* Recover genuinely corrupt data below; never downgrade a newer save. */ }
        }
        let backups = try backupURLs()
        if !exists && backups.isEmpty { return Loaded(state: GameState(), recovered: false) }
        for backup in backups {
            guard let data = try? Data(contentsOf: backup), let state = try? Self.decode(data) else { continue }
            if exists {
                // Keep each corrupt original, even across repeated recovery attempts.
                try fm.copyItem(at: url, to: url.appendingPathExtension("corrupt-\(UUID().uuidString)"))
            }
            try data.write(to: url, options: .atomic)
            return Loaded(state: state, recovered: true)
        }
        throw Failure.unrecoverable
    }

    func commit(_ state: GameState) throws {
        let fm = FileManager.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        _ = try Self.decode(data)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            _ = try Self.decode(previous)
            try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let stamp = String(format: "%020.6f", Date().timeIntervalSince1970)
            let backup = backupDirectory.appendingPathComponent("\(stamp)-\(UUID().uuidString).json")
            try previous.write(to: backup, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        // Cleanup cannot turn a successful durable commit into a reported failure.
        for old in (try? backupURLs())?.dropFirst(Self.retainedBackups) ?? [] {
            do { try fm.removeItem(at: old) }
            catch { AppLog.write("save backup pruning failed: \(error.localizedDescription)") }
        }
    }

    func backupURLs() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: backupDirectory,
            includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
