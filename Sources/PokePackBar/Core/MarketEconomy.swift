import Foundation

/// 게임의 토큰과 실제 시세를 잇는 단 하나의 지점.
///
/// 예전에는 카드값을 등급표로 매겼다. 실제 시장은 등급 순서를 따르지 않는다 — 우리가 최상위로
/// 두던 UR 의 중앙값이 SAR 의 6분의 1이고, 같은 세트·같은 등급 안에서도 40배가 벌어진다.
/// 그래서 값은 전부 시세에서 나오고, 여기 있는 두 상수만이 그것을 게임 안의 숫자로 옮긴다.
///
/// ```
/// 분해값(카드) = 시세 × tokensPerUSD
/// 팩값(세트)   = max(밀봉 부스터 시세, 카드 기대 시세 × packMargin) × tokensPerUSD
/// ```
///
/// 밀봉 팩과 낱장 카드가 같은 환율을 쓴다. 수집품 프리미엄이 큰 오래된 팩은 실제 시세를
/// 유지하고, 낱장 기대값이 비정상적으로 더 큰 데이터에서는 무한 되팔이를 막는 하한을 둔다.
enum MarketEconomy {

    /// 1달러가 몇 토큰인가.
    ///
    /// 밀봉 팩·낱장 카드·오리파가 같은 환율을 쓴다.
    static let tokensPerUSD: Double = 292_000

    /// 카드 기대값이 밀봉 부스터 시세보다 높은 세트에 쓰는 안전 하한 마진.
    ///
    /// 곧 "사서 갈기만 할 때 돌려받는 비율" 의 역수다. 최대 도감 히트·판매 혜택과
    /// 반값 쿠폰까지 적용해도 장기 기대 환급이 구매가의 90% 아래에 머물도록 잡았다.
    /// 쿠폰과 영구 할인은 `WalletStore` 에서 더 강한 하나만 적용한다.
    static let packMargin: Double = 3.4

    /// 시세를 모르는 카드에 쓸 값. 0 으로 두면 갈 수도 없는 카드가 된다.
    static let unknownUSD: Double = 0.05

    /// 값의 최소 단위(원). 이보다 잘게 매기지 않는다.
    ///
    /// 예전에는 토큰으로 값을 매기고 화면에서만 천 단위로 반올림했다. 그러면 **적힌 값과
    /// 실제로 빠지는 값이 달라진다** — 3,006,432원짜리 팩이 3,006,000원으로 보여서 살 수
    /// 있을 것 같은데 못 사고, 사고 나면 남은 돈이 계산과 맞지 않는다. 이제 값 자체가
    /// 100원 칸에만 존재하고, 화면은 그것을 그대로 적는다.
    static let wonStep = 100

    /// 100원 한 칸이 몇 토큰인가. 스냅샷 환율에서 나오므로 배포 안에서는 고정이다.
    static func stepTokens(_ prices: CardPrices? = CardPrices.shared) -> Int {
        guard let prices, prices.krwPerUSD > 0 else { return 1 }
        return max(1, Int((Double(wonStep) * tokensPerUSD / prices.krwPerUSD).rounded()))
    }

    /// 토큰 값을 100원 칸에 맞춰 끊는다. **모든 가격은 이 함수를 지나야 한다.**
    ///
    /// 할인이나 추가금을 곱하면 칸에서 벗어나므로, 곱한 **뒤에** 다시 끊는다.
    static func quantized(_ tokens: Int, prices: CardPrices? = CardPrices.shared) -> Int {
        let step = stepTokens(prices)
        guard step > 1 else { return max(1, tokens) }
        return max(step, ((tokens + step / 2) / step) * step)
    }

    /// 달러를 토큰으로. 100원 칸에 맞춰 끊는다.
    static func tokens(usd: Double, prices: CardPrices? = CardPrices.shared) -> Int {
        quantized(max(1, Int((usd * tokensPerUSD).rounded())), prices: prices)
    }

    /// 토큰을 원으로.
    ///
    /// 칸의 배수는 **정확히** 100원의 배수로 돌아와야 한다. 실수로 나누면 1,000칸쯤에서
    /// 1원이 어긋나 화면의 값이 가격과 달라진다. 칸 단위는 정수로 세고 나머지만 환산한다.
    static func won(tokens: Int, prices: CardPrices? = CardPrices.shared) -> Int {
        guard let prices else { return 0 }
        let step = stepTokens(prices)
        guard step > 1 else {
            return Int((Double(tokens) / tokensPerUSD * prices.krwPerUSD).rounded())
        }
        // 남는 토큰은 **버린다.** 반올림하면 한 칸에서 1토큰 모자란 잔액이 그 칸을 채운 것으로
        // 보여, 살 수 있다고 나오는데 실제로는 못 사는 경우가 다시 생긴다.
        let steps = tokens / step
        let rest = tokens % step
        return steps * wonStep + Int(Double(rest) / Double(step) * Double(wonStep))
    }

    /// 토큰 금액을 화면에 쓸 원화 문자열로.
    static func money(tokens: Int, language: AppLanguage,
                      prices: CardPrices? = CardPrices.shared) -> String {
        WonFormatter.money(won(tokens: tokens, prices: prices), language: language)
    }

    static func usd(cardID: String, prices: CardPrices?) -> Double {
        prices?.price(cardID) ?? unknownUSD
    }

    /// 특정 인쇄본의 시세. v2 가격표처럼 판형 값이 없으면 `CardPrices` 가 카드 대표값으로
    /// 폴백하므로, 호출부는 스냅샷 버전을 따로 알 필요가 없다.
    static func usd(cardID: String, finish: CardFinish, prices: CardPrices?) -> Double {
        prices?.price(cardID: cardID, finish: finish) ?? unknownUSD
    }

    static func usd(_ printing: CardPrintingKey, prices: CardPrices?) -> Double {
        usd(cardID: printing.cardID, finish: printing.finish, prices: prices)
    }

    /// 한 세트에서 그 등급 카드의 평균 시세.
    ///
    /// 팩 기대값은 "이 칸에서 이 등급이 나올 확률" 까지만 아는데, 같은 등급 안에서도 값이
    /// 크게 갈리므로 평균을 써야 한다.
    static func meanUSD(setID: String, tier: CardTier,
                        index: CardIndex, prices: CardPrices?) -> Double {
        let ids = index.pools[setID]?[tier] ?? []
        guard !ids.isEmpty else { return 0 }
        return ids.reduce(0.0) { $0 + usd(cardID: $1, prices: prices) } / Double(ids.count)
    }

    /// 팩 하나에 들어 있는 것의 기대 시세(달러).
    ///
    /// 확률은 `PackOpening.packOdds` 를 그대로 쓴다. 세트 전용 특수팩은 반영하지만,
    /// 플레이어마다 현재 카운터가 다른 천장은 가격에서 제외한 무혜택 기준선이다.
    /// 등급 평균만으로는 정확한 카드가 정해진 특수팩과 병렬판형 가격이 사라지므로 그 차이만
    /// `printingAdjustmentUSD` 에서 더한다.
    ///
    /// **혜택은 넣지 않는다.** 카드를 한 장 더 받는 혜택까지 반영하면 혜택을 얻은 사람의
    /// 팩값이 올라간다 — 혜택이 벌이 되어서는 안 된다.
    static func packValueUSD(setID: String, index: CardIndex, prices: CardPrices?) -> Double {
        let odds = PackOpening.packOdds(setID: setID, index: index)   // 혜택 제외 — 아래 주석
        guard !odds.isEmpty else { return 0 }
        let cards = Double(PackPricing.cardCount(setID: setID, index: index))   // 혜택 제외
        let tierValue = odds.reduce(0.0) {
            $0 + $1.probability * cards * meanUSD(setID: setID, tier: $1.tier,
                                                  index: index, prices: prices)
        }
        return max(0, tierValue + printingAdjustmentUSD(setID: setID, index: index,
                                                         prices: prices))
    }

    /// `packOdds`가 등급 평균으로 세어 둔 값을 실제 고정 카드·판형 가격으로 교체하는 보정값.
    private static func printingAdjustmentUSD(setID: String, index: CardIndex,
                                               prices: CardPrices?) -> Double {
        let recipe = PackRecipe.forSet(setID, era: index.era(setID))
        let pool = index.pools[setID] ?? [:]
        let specialChance = recipe.specialVariant.map {
            1.0 / Double($0.estimatedSimulatorOneIn)
        } ?? 0

        var adjustment = 0.0

        // Subsets and some legacy reverse sheets use only part of a rarity
        // tier. Replace the tier-average contribution with the exact slot pool
        // and finish while keeping `packOdds` as the public rarity disclosure.
        let tables = PackConfig.slotTables(setID: setID, era: index.era(setID))
        for (slot, table) in zip(recipe.slots, tables) {
            let slotPool = PackOpening.slotPool(
                setID: setID, slot: slot.kind, pool: pool, index: index
            )
            let weights = slot.kind == .radiantCollectionHigh
                ? table.weights
                : PackConfig.weights(table.weights, perks: .none)
            let available = weights.filter { !(slotPool[$0.tier] ?? []).isEmpty }
            let totalWeight = available.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else { continue }

            for entry in available {
                let ids = slotPool[entry.tier] ?? []
                guard !ids.isEmpty else { continue }
                let hint = PackOpening.finishHint(
                    setID: setID, slot: slot.kind,
                    tier: entry.tier, era: index.era(setID)
                )
                let actualMean = ids.reduce(0.0) { total, cardID in
                    let pulled = PulledCard(id: cardID, tier: entry.tier, isNew: false)
                    let printing = PackSlotResult(card: pulled, finishHint: hint)
                        .printing(setID: setID, index: index)
                    return total + usd(printing, prices: prices)
                } / Double(ids.count)
                let tierMean = meanUSD(setID: setID, tier: entry.tier,
                                       index: index, prices: prices)
                let probability = Double(entry.weight) / Double(totalWeight)
                let parallelChance = Double(PackRecipe.observedParallelHits(setID: setID, slot: slot.kind) ?? 0)
                    / Double(PackRecipe.prismaticParallelRolls)
                adjustment += (actualMean - tierMean)
                    * probability * Double(slot.count) * recipe.standardShare(for: slot.kind) * (1 - parallelChance)
            }
        }

        for slot in recipe.slots {
            guard let hits = PackRecipe.observedParallelHits(setID: setID, slot: slot.kind)
            else { continue }
            let isMasterBall = slot.kind == .reverseHoloHit
            let finish: CardFinish = isMasterBall ? .masterBall : .pokeBall
            let candidates = PackOpening.prismaticParallelCandidates(
                setID: setID,
                pool: pool,
                masterBallOnly: isMasterBall
            )
            guard !candidates.isEmpty else { continue }

            let actualMean = candidates.reduce(0.0) {
                $0 + usd(cardID: $1.id, finish: finish, prices: prices)
            } / Double(candidates.count)
            let tierMeanAlreadyCounted = candidates.reduce(0.0) {
                $0 + meanUSD(setID: setID, tier: $1.tier, index: index, prices: prices)
            } / Double(candidates.count)
            let chance = Double(hits) / Double(PackRecipe.prismaticParallelRolls)
            adjustment += (actualMean - tierMeanAlreadyCounted)
                * chance * recipe.standardShare(for: slot.kind) * Double(slot.count)
        }

        func requestsAdjustment(_ requests: [PackCardRequest]) -> Double {
            requests.reduce(0.0) { total, request in
                let ids = request.exactCardID.map { [$0] } ?? (pool[request.tier] ?? [])
                guard !ids.isEmpty else { return total }
                let delta = ids.reduce(0.0) { sum, cardID in
                    guard let entry = index.card(cardID), entry.setID == setID else { return sum }
                    let pulled = PulledCard(id: cardID, tier: entry.tier, isNew: false)
                    let printing = PackSlotResult(card: pulled, finishHint: request.finishHint)
                        .printing(setID: setID, index: index)
                    return sum + usd(printing, prices: prices)
                        - meanUSD(setID: setID, tier: entry.tier, index: index, prices: prices)
                } / Double(ids.count)
                return total + delta
            }
        }

        switch recipe.specialVariant?.variant {
        case .scarletViolet151Demigod:
            let lineMean = PackRecipe.scarletViolet151Lines
                .map(requestsAdjustment)
                .reduce(0, +) / Double(PackRecipe.scarletViolet151Lines.count)
            adjustment += lineMean * specialChance
        case .prismaticEvolutionsGod:
            adjustment += requestsAdjustment(PackRecipe.prismaticEvolutionsGodPack)
                * specialChance
            adjustment += requestsAdjustment(Array(repeating: PackCardRequest(tier: .specialArtRare), count: 3))
                * specialChance
        case .blackBoltWhiteFlareGod:
            adjustment += requestsAdjustment(PackRecipe.blackBoltWhiteFlareGodPack) * specialChance
        case .ascendedHeroesGod:
            adjustment += requestsAdjustment(PackRecipe.ascendedHeroesGodPack) * specialChance
        case .standard, .celebrations, .prismaticEvolutionsDemigod, nil:
            break
        }
        return adjustment
    }
}
