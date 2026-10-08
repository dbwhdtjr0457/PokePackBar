import Foundation

/// 팩(세트)을 이름으로 찾는다.
///
/// 화면에 보이는 세트 이름은 어느 언어에서나 영어 원문이라 그것을 기준으로 한다. 시대 이름,
/// 세트 ID, 발매 연도도 함께 맞춰 「sun moon」, 「sv3」, 「2023」 으로도 찾을 수 있다.
/// 띄어 쓴 낱말은 모두 맞아야 한다 — 「scarlet 151」 은 151 하나만 남긴다.
enum PackSearch {
    /// 맞는 세트를 잘 맞는 순서로. 같으면 최신 세트가 앞이다(상점과 팩 탭의 순서).
    static func results(_ query: String, in sets: [CardSet]) -> [CardSet] {
        let tokens = tokens(query)
        guard !tokens.isEmpty else { return [] }
        var found: [Found] = []
        for set in sets {
            if let rank = score(set, tokens: tokens) { found.append(Found(set: set, rank: rank)) }
        }
        return found.sorted(by: Found.precedes).map(\.set)
    }

    private struct Found {
        let set: CardSet
        let rank: Int

        static func precedes(_ lhs: Found, _ rhs: Found) -> Bool {
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.set.released != rhs.set.released { return lhs.set.released > rhs.set.released }
            return lhs.set.name < rhs.set.name
        }
    }

    static func matches(_ set: CardSet, query: String) -> Bool {
        let tokens = tokens(query)
        return tokens.isEmpty || score(set, tokens: tokens) != nil
    }

    /// 영어 이름에 없는 글자(한글, 가나 등)가 들어 있는가. 그럴 때는 이름이 영어라고 알려 준다.
    static func hasNonLatinLetters(_ query: String) -> Bool {
        query.unicodeScalars.contains { $0.properties.isAlphabetic && !$0.isASCII }
    }

    private static func tokens(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace)
            .map { DexCardSearch.normalized(String($0)) }
            .filter { !$0.isEmpty }
    }

    /// 낮을수록 잘 맞는다. 낱말 하나라도 어디에도 안 맞으면 nil.
    private static func score(_ set: CardSet, tokens: [String]) -> Int? {
        let name = DexCardSearch.normalized(set.name)
        let words = set.name.split { !$0.isLetter && !$0.isNumber }
            .map { DexCardSearch.normalized(String($0)) }
        let series = DexCardSearch.normalized(set.series)
        let id = DexCardSearch.normalized(set.id)
        var total = 0
        for token in tokens {
            let rank: Int
            if name.hasPrefix(token) { rank = 0 }
            else if words.contains(where: { $0.hasPrefix(token) }) { rank = 1 }
            else if name.contains(token) { rank = 2 }
            else if series.contains(token) { rank = 3 }
            else if id.hasPrefix(token) { rank = 4 }
            else if set.year.hasPrefix(token) { rank = 5 }
            else { return nil }
            total += rank
        }
        // 띄어쓰기 없이 친 이름(「sunmoon」)이나 기호를 뺀 이름도 낱말 하나로 맞춘다.
        if tokens.count > 1, name.contains(tokens.joined()) { total = min(total, 1) }
        // 이름이나 세트 ID 를 그대로 쳤으면 맨 앞이다. 「base」 는 Base Set 2 보다 Base 가,
        // 「sv3」 은 151(sv3pt5) 보다 Obsidian Flames(sv3) 가 먼저다.
        if name == tokens.joined() || (tokens.count == 1 && id == tokens[0]) { total = -1 }
        return total
    }
}
