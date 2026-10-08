import SwiftUI

/// 온라인 창의 축하 순간. 지금은 교환 성사 하나다.
struct OnlineCelebration: Identifiable, Equatable {
    let id = UUID()
    /// 내가 보낸 카드와 받은 카드(대표 한 장씩, 출력 키).
    let gave: String?
    let got: String?
}

/// 교환이 성사된 순간. 보낸 카드와 받은 카드가 서로 자리를 바꾸고 반짝인다.
///
/// 수락을 누르면 목록의 상태 표시만 바뀌어, 카드가 실제로 오갔다는 느낌이 없었다.
/// 두 카드가 엇갈려 지나가면 무엇을 주고 무엇을 받았는지가 한눈에 보인다.
@MainActor
struct TradeSwapBanner: View {
    let celebration: OnlineCelebration
    @State private var swapped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardWidth: CGFloat = 70

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                card(celebration.gave)
                    .rotationEffect(.degrees(swapped ? 7 : -7))
                    .offset(x: swapped ? 46 : -46, y: swapped ? 6 : 0)
                    .zIndex(swapped ? 0 : 1)
                    .opacity(swapped ? 0.8 : 1)
                card(celebration.got)
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
