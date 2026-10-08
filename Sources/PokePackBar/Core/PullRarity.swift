import Foundation

/// 그 세트 팩에서 그 등급이 얼마나 드물게 나오는가.
///
/// 공개 연출은 등급 이름으로 세기를 정했었다. 그러면 팩마다 거의 한 장씩 나오는 R 도 파란
/// 불꽃이 터지고, 30주년 팩처럼 피카츄 레어가 매 팩 한 장씩 고정으로 들어 있는 팩에서는 매번
/// 같은 축하가 반복됐다. 「얼마나 드문가」는 등급 이름이 아니라 그 팩의 칸 구성이 정한다.
///
/// 한 팩을 열었을 때 그 등급이 한 장 이상 나올 확률을 칸 구성에서 바로 센다. 칸마다
/// 독립으로 보고 1 - Π(1 - p)^칸수 로 합친다. 갓팩 같은 특수팩이 칸을 대신하는 몫은 뺀다.
enum PullRarity {
    /// 팩마다의 등급별 확률. 세트 구성은 실행 중에 바뀌지 않으므로 한 번만 센다.
    nonisolated(unsafe) private static var cache: [String: [CardTier: Double]] = [:]
    private static let lock = NSLock()

    /// 한 팩에 이 등급이 한 장 이상 들어 있을 확률. 이 세트 팩에서 나오지 않는 등급이면 nil 이다.
    static func chancePerPack(setID: String, tier: CardTier,
                              index: CardIndex? = CardIndex.shared) -> Double? {
        guard let index else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if cache[setID] == nil { cache[setID] = compute(setID: setID, index: index) }
        guard let chance = cache[setID]?[tier], chance > 0 else { return nil }
        return chance
    }

    /// 몇 팩에 한 번 나오는가.
    static func packsPerPull(setID: String, tier: CardTier,
                             index: CardIndex? = CardIndex.shared) -> Double? {
        chancePerPack(setID: setID, tier: tier, index: index).map { 1 / $0 }
    }

    nonisolated(unsafe) private static var cardCache: [String: [String: Double]] = [:]

    /// 이 카드가 들어 있는 칸에서 같은 등급이 한 장 이상 나올 확률.
    ///
    /// 같은 등급이라도 칸이 다르면 드묾이 다르다. 30주년의 피카츄 레어는 매 팩 고정 칸에서,
    /// 일러스트레어는 셋째 칸에서 다섯 팩에 한 장 나오는데 둘 다 AR 이다. 등급 하나로 세면
    /// 일러스트레어도 「매 팩 나온다」가 되어 연출이 사라진다. 칸 풀에 없는 카드(특수팩에서만
    /// 나오는 카드)는 등급 단위 값으로 떨어진다.
    static func chancePerPack(setID: String, cardID: String, tier: CardTier,
                              index: CardIndex? = CardIndex.shared) -> Double? {
        guard let index else { return nil }
        lock.lock()
        if cardCache[setID] == nil { cardCache[setID] = computeCards(setID: setID, index: index) }
        let chance = cardCache[setID]?[cardID]
        lock.unlock()
        if let chance, chance > 0 { return chance }
        return chancePerPack(setID: setID, tier: tier, index: index)
    }

    static func packsPerPull(setID: String, cardID: String, tier: CardTier,
                             index: CardIndex? = CardIndex.shared) -> Double? {
        chancePerPack(setID: setID, cardID: cardID, tier: tier, index: index).map { 1 / $0 }
    }

    /// 연출 단계의 경계. 팩 수로 적는다 — 「몇 팩에 한 번」이 사람이 드묾을 재는 단위다.
    enum Threshold {
        /// 이보다 자주 나오면 연출이 없다. 네 팩에 한 번꼴이면 손에 익은 카드다.
        static let rare = 4.0
        static let premium = 12.0
        static let apex = 40.0
        /// 이보다 드물면 가장 높은 단계다. 한 박스(36팩)를 몇 개 열어야 한 장 볼까 말까 하다.
        static let mythic = 150.0
    }

    static func emphasis(packsPerPull packs: Double) -> RevealEmphasis {
        switch packs {
        case ..<Threshold.rare: .none
        case ..<Threshold.premium: .rare
        case ..<Threshold.apex: .premium
        case ..<Threshold.mythic: .apex
        default: .mythic
        }
    }

    private static func compute(setID: String, index: CardIndex) -> [CardTier: Double] {
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)
        let tables = PackConfig.slotTables(setID: setID, era: era)
        let pool = index.pools[setID] ?? [:]
        var miss: [CardTier: Double] = [:]
        for (slot, table) in zip(recipe.slots, tables) {
            let slotPool = PackOpening.slotPool(setID: setID, slot: slot.kind, pool: pool, index: index)
            let weights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: .none)
            // 카드가 없는 등급은 실제로 뽑히지 않는다. 그 몫은 남은 등급이 나눠 갖는다.
            let available = weights.filter { $0.weight > 0 && !(slotPool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0 else { continue }
            let share = recipe.standardShare(for: slot.kind)
            for entry in available {
                let chance = Double(entry.weight) / Double(total) * share
                miss[entry.tier, default: 1] *= pow(1 - chance, Double(slot.count))
            }
        }
        return miss.mapValues { 1 - $0 }
    }

    /// 카드마다 그 카드가 들어 있는 칸들만 곱한다.
    private static func computeCards(setID: String, index: CardIndex) -> [String: Double] {
        let era = index.era(setID)
        let recipe = PackRecipe.forSet(setID, era: era)
        let tables = PackConfig.slotTables(setID: setID, era: era)
        let pool = index.pools[setID] ?? [:]
        var miss: [String: Double] = [:]
        for (slot, table) in zip(recipe.slots, tables) {
            let slotPool = PackOpening.slotPool(setID: setID, slot: slot.kind, pool: pool, index: index)
            let weights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: .none)
            let available = weights.filter { $0.weight > 0 && !(slotPool[$0.tier] ?? []).isEmpty }
            let total = available.reduce(0) { $0 + $1.weight }
            guard total > 0 else { continue }
            let share = recipe.standardShare(for: slot.kind)
            for entry in available {
                let chance = Double(entry.weight) / Double(total) * share
                for id in slotPool[entry.tier] ?? [] {
                    miss[id, default: 1] *= pow(1 - chance, Double(slot.count))
                }
            }
        }
        return miss.mapValues { 1 - $0 }
    }
}
