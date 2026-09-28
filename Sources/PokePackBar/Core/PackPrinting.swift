import Foundation

/// 팩의 물리 슬롯 힌트와 카드 메타데이터를 실제 보유 인쇄본으로 합친다.
///
/// 슬롯은 `reverse holo`처럼 카드 번호만으로 알 수 없는 정보를 주고, 카드 메타데이터는
/// `Radiant`, `Gold`, `SIR`처럼 그 카드 고유의 재질을 준다. 둘 중 더 구체적인 쪽을 택한다.
extension PackSlotResult {
    func printing(setID: String, index: CardIndex) -> CardPrintingKey {
        let entry = index.card(card.id)
        let inferred = CardFinishResolver.resolve(
            cardID: card.id,
            setID: entry?.setID ?? setID,
            originalRarity: entry?.rarity,
            tier: card.tier
        ).finish

        let finish: CardFinish
        switch finishHint {
        case .normal:
            finish = .normal
        case .reverseHolo:
            finish = .reverseHolo
        case .ascendedParallel:
            // Each eligible Pokémon has ONE specified ball/R printing. Trainer
            // and Energy cards retain their plain reverse, never a random ball.
            finish = ExpansionFoil.parallels[card.id] == nil ? .reverseHolo : .patternedReverse
        case .holoRare:
            finish = .holo
        case .allFoil:
            // Celebrations의 보통 Rare만 holo로 승격한다. Classic·Gold 등 이미 더
            // 구체적인 재질이 있는 카드는 그 재질을 지우지 않는다.
            finish = inferred == .normal ? .holo : inferred
        case .defaultForCard:
            finish = inferred
        case .pokeBallParallel:
            finish = .pokeBall
        case .masterBallParallel:
            finish = .masterBall
        }
        return CardPrintingKey(cardID: card.id, finish: finish)
    }
}
