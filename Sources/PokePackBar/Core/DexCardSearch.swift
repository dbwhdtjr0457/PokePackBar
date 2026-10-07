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

    /// 카드마다 검색에 쓰는 정규화한 이름(원문, 한국어).
    ///
    /// 정규화는 글자마다 문자열을 새로 만들어서, 1만 9천 장을 화면을 그릴 때마다 다시 하면
    /// 80ms 가 걸렸다. 검색어가 있는 동안 카드 그림이 도착하거나 상태가 바뀔 때마다 화면이
    /// 끊긴 원인이다. 처음 쓸 때 한 번만 만들고, 기동할 때 백그라운드에서 미리 만든다.
    static let normalizedNames: [String: [String]] = {
        guard let index = CardIndex.shared else { return [:] }
        var names: [String: [String]] = [:]
        names.reserveCapacity(index.cards.count)
        for entry in index.cards { names[entry.id] = [entry.name, entry.nameKo].compactMap { $0 }.map(normalized) }
        return names
    }()

    /// 번호 검색용. "4/102" 전체와 "4" 처럼 앞부분만 친 경우를 함께 맞춘다.
    struct NumberKey: Sendable { let full: String; let head: String }
    static let normalizedNumbers: [String: NumberKey] = {
        guard let index = CardIndex.shared else { return [:] }
        var numbers: [String: NumberKey] = [:]
        numbers.reserveCapacity(index.cards.count)
        for entry in index.cards {
            guard let label = index.numberLabel(entry.id) else { continue }
            numbers[entry.id] = NumberKey(full: normalized(label),
                                          head: normalized(String(label.split(separator: "/").first ?? "")))
        }
        return numbers
    }()

    static func names(_ entry: CardEntry) -> [String] {
        normalizedNames[entry.id] ?? [entry.name, entry.nameKo].compactMap { $0 }.map(normalized)
    }

    static func names(cardID: String) -> [String] {
        if let names = normalizedNames[cardID] { return names }
        return CardIndex.shared?.card(cardID).map(names) ?? []
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
            guard names(card).contains(where: { $0.contains(needle) }) else { continue }
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
