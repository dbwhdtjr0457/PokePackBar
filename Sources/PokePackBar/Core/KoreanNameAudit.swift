import Foundation

/// Checks the same decoded names used below card images, without starting WalletStore.
@MainActor
enum KoreanNameAudit {
    static func verifyNames(_ index: CardIndex) throws {
        for card in index.cards {
            guard let korean = card.nameKo, !korean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalAudit.Failure(description: "Missing Korean name: \(card.id)")
            }
            try LocalAudit.require(card.displayName(.ko) == korean, "Korean display fallback: \(card.id)")
            try LocalAudit.require(card.displayName(.en) == card.name, "English name changed: \(card.id)")
        }
    }

    static func verify(index: CardIndex) throws {
        try verifyNames(index)
        let fixtures = ["cel30-R_RGB": "뮤", "me2pt5-22": "메가리자몽Y ex",
                        "me3-75": "유카리", "me4-75": "앙쥬 플라엣테", "me5-78": "무쿠",
                        "cel25c-24_A": "_____의 피카츄", "swsh12tg-TG26": "버넷박사"]
        for (id, name) in fixtures {
            try LocalAudit.require(index.card(id)?.displayName(.ko) == name, "Korean fixture: \(id)")
        }
        guard let url = AppResources.bundle?.url(forResource: "card-index", withExtension: "json") else {
            throw LocalAudit.Failure(description: "Missing catalogue for Korean regression")
        }
        let data = try Data(contentsOf: url)
        // Reproduce the actual importer omission against the current catalogue.
        var partial = CardIndex.loadKoreanNames()
        partial.removeValue(forKey: "cel30-R_RGB")
        guard let missing = CardIndex.decode(data, korean: partial),
              let empty = CardIndex.decode(data, korean: [:]) else {
            throw LocalAudit.Failure(description: "Cannot decode Korean regression fixtures")
        }
        for mutation in [missing, empty] {
            var rejected = false
            do { try verifyNames(mutation) } catch { rejected = true }
            try LocalAudit.require(rejected, "Korean guard accepted missing translations")
        }
        print("PASS Korean names: \(index.cards.count) decoded Korean/English labels; new-set fixtures and missing-name mutations; wallet untouched")
    }
}
