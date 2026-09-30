import Foundation

/// 도감에서 카드 이름으로 해당 카드를 포함하는 조합·세트를 찾는다.
///
/// 화면의 현재 언어와 관계없이 한국어와 원문 이름을 함께 찾는다. 한국어 UI에서 영문 카드명을
/// 기억하는 경우와, 번역이 아직 없는 카드 모두 같은 검색창으로 찾을 수 있어야 하기 때문이다.
enum DexCardSearch {
    static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    static func containsCard(named query: String, in dex: Dex, index: CardIndex) -> Bool {
        !matches(named: query, in: dex, index: index, limit: 1).isEmpty
    }

    static func matches(named query: String, in dex: Dex, index: CardIndex,
                        limit: Int = .max) -> [CardEntry] {
        let needle = normalized(query)
        guard !needle.isEmpty, limit > 0 else { return [] }

        var result: [CardEntry] = []
        for card in cards(in: dex, index: index) {
            let names = [card.name, card.nameKo].compactMap { $0 }
            guard names.contains(where: { normalized($0).contains(needle) }) else { continue }
            result.append(card)
            if result.count == limit { break }
        }
        return result
    }

    private static func cards(in dex: Dex, index: CardIndex) -> [CardEntry] {
        let ids = dex.kind == .set ? index.cards(inSet: dex.homeSet) : dex.cards
        return ids.compactMap(index.card)
    }
}
