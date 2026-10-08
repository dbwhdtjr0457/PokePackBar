import SwiftUI

/// 온라인 창의 축하 순간. 교환 성사, 마켓 구매, 판매 등록.
struct OnlineCelebration: Identifiable, Equatable {
    enum Kind: Equatable {
        /// 내가 보낸 카드와 받은 카드(대표 한 장씩, 출력 키).
        case trade(gave: String?, got: String?)
        /// 마켓에서 산 카드와 장수.
        case bought(printing: String, quantity: Int)
        /// 판매로 올린 카드.
        case listed(printing: String)
    }
    let id = UUID()
    let kind: Kind
}

/// 축하 순간을 종류에 맞는 연출로 고른다.
@MainActor
struct OnlineCelebrationView: View {
    let celebration: OnlineCelebration

    var body: some View {
        switch celebration.kind {
        case .trade(let gave, let got):
            TradeSwapBanner(gave: gave, got: got)
        case .bought(let printing, let quantity):
            CardMomentBanner(printing: printing, title: OnlineText.l.marketBought(quantity),
                             symbol: "cart.fill.badge.plus", tint: .accentColor)
        case .listed(let printing):
            CardMomentBanner(printing: printing, title: OnlineText.l.marketListed,
                             symbol: "tag.fill", tint: .orange)
        }
    }
}

/// 카드 한 장의 순간(산 카드, 내놓은 카드). 카드가 톡 떠오르고 반짝인다.
@MainActor
private struct CardMomentBanner: View {
    let printing: String
    let title: String
    let symbol: String
    let tint: Color
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            CardImageView(cardID: CardPrintingKey(storageKey: printing).cardID, width: 84)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .scaleEffect(landed ? 1 : 0.7)
                .offset(y: landed ? 0 : 14)
                .background { if landed { SparkBurst(color: tint, radius: 62) } }
            Label(title, systemImage: symbol)
                .font(Typography.bodySemibold)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 26).padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35), lineWidth: 1) }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .onAppear {
            if reduceMotion { landed = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.68).delay(0.08)) { landed = true }
        }
    }
}

/// 교환이 성사된 순간. 보낸 카드와 받은 카드가 서로 자리를 바꾸고 반짝인다.
///
/// 수락을 누르면 목록의 상태 표시만 바뀌어, 카드가 실제로 오갔다는 느낌이 없었다.
/// 두 카드가 엇갈려 지나가면 무엇을 주고 무엇을 받았는지가 한눈에 보인다.
@MainActor
struct TradeSwapBanner: View {
    let gave: String?
    let got: String?
    @State private var swapped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardWidth: CGFloat = 70

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                card(gave)
                    .rotationEffect(.degrees(swapped ? 7 : -7))
                    .offset(x: swapped ? 46 : -46, y: swapped ? 6 : 0)
                    .zIndex(swapped ? 0 : 1)
                    .opacity(swapped ? 0.8 : 1)
                card(got)
                    .rotationEffect(.degrees(swapped ? -7 : 7))
                    .offset(x: swapped ? -46 : 46, y: swapped ? -6 : 0)
                    .zIndex(swapped ? 1 : 0)
                    .background { if swapped { SparkBurst(color: .green, radius: 60) } }
            }
            .frame(width: Self.cardWidth * 2 + 70, height: (Self.cardWidth / 0.717).rounded() + 16)
            Label(OnlineText.l.tradeCompleted, systemImage: "arrow.left.arrow.right.circle.fill")
                .font(Typography.bodySemibold)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.green.opacity(0.35), lineWidth: 1) }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .onAppear {
            if reduceMotion { swapped = true; return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.74).delay(0.2)) { swapped = true }
        }
    }

    @ViewBuilder
    private func card(_ printing: String?) -> some View {
        if let printing {
            CardImageView(cardID: CardPrintingKey(storageKey: printing).cardID, width: Self.cardWidth)
                .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
        } else {
            RoundedRectangle(cornerRadius: Self.cardWidth * 0.05)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: Self.cardWidth, height: (Self.cardWidth / 0.717).rounded())
        }
    }
}
