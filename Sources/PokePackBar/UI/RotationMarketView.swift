import SwiftUI

/// 상점의 로테이션 갈래. 오늘의 8장을 시세 기준가에 한 장씩 판다.
@MainActor
struct RotationMarketView: View {
    let wallet: WalletStore
    let index: CardIndex

    @State private var buying: String?
    @State private var notice: String?
    @State private var failed = false
    @State private var spotlight: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private var cardWidth: CGFloat { ((PopoverMetrics.contentWidth - 8 * 3 - 4) / 4).rounded(.down) }

    var body: some View {
        if let spotlight, let entry = index.card(spotlight) {
            CardSpotlightView(wallet: wallet, cardID: entry.id,
                              name: entry.displayName(wallet.language),
                              tier: entry.tier, setID: entry.setID,
                              setName: index.set(entry.setID)?.name ?? entry.setID,
                              rarity: entry.rarity,
                              ownedCount: wallet.cardCount(entry.id)) {
                self.spotlight = nil
            }
        } else {
            lineup
        }
    }

    private var lineup: some View {
        let l = wallet.l
        let date = RotationMarket.dateKey()
        let cards = wallet.rotationLineup(index: index, date: date)
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l.rotationTitle).font(Typography.title)
                    Spacer(minLength: 4)
                    // 분 단위면 충분하다. 매초 다시 그릴 이유가 없다.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(l.rotationNext(RotationMarket.untilNextLineup(context.date)))
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Text(l.rotationHint)
                    .font(Typography.label).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let notice {
                    Label(notice, systemImage: failed ? "exclamationmark.circle" : "checkmark.circle.fill")
                        .font(Typography.label)
                        .foregroundStyle(failed ? Color.orange : Color.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: Self.columns, spacing: 10) {
                    ForEach(cards, id: \.self) { cardID in
                        cell(cardID, date: date)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func cell(_ cardID: String, date: String) -> some View {
        let l = wallet.l
        let entry = index.card(cardID)
        let price = wallet.rotationPrice(cardID, index: index)
        let bought = wallet.rotationBought(cardID, date: date)
        let affordable = wallet.availableTokens >= price
        return VStack(spacing: 4) {
            Button { spotlight = cardID } label: {
                CardImageView(cardID: cardID, width: cardWidth)
                    .opacity(bought ? 0.55 : 1)
                    .overlay(alignment: .topTrailing) {
                        if bought {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white, Color.green)
                                .padding(3)
                        }
                    }
                    .hoverLift(scale: 1.04)
            }
            .buttonStyle(.plain)
            .help(entry?.displayName(wallet.language) ?? cardID)
            if let entry {
                Text(l.tierBadge(entry.tier))
                    .font(Typography.badge)
                    .foregroundStyle(tierColor(entry.tier))
            }
            Text(MarketEconomy.money(tokens: price, language: wallet.language))
                .font(Typography.labelSemibold).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Button(bought ? l.rotationBought : (affordable ? l.rotationBuy : l.rotationNotEnough)) {
                buy(cardID)
            }
            .buttonStyle(.bordered)
            .font(Typography.button)
            .lineLimit(1).minimumScaleFactor(0.7)
            .disabled(bought || !affordable || buying != nil || wallet.resourceActionsDisabled)
        }
    }

    private func buy(_ cardID: String) {
        buying = cardID
        Task {
            defer { buying = nil }
            let card = await wallet.buyRotationOnlineAware(cardID: cardID, index: index)
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                if let card {
                    failed = false
                    notice = wallet.l.rotationBoughtNotice(index.card(card.id)?.displayName(wallet.language) ?? card.id)
                    SoundEffects.play(.pop)
                } else {
                    failed = true
                    notice = wallet.persistenceError ?? wallet.l.rotationFailed
                }
            }
        }
    }
}
