import SwiftUI

/// 카드 공개 연출의 한 가지 기준점.
///
/// 화면마다 임의로 지연과 빛의 세기를 정하면 같은 카드가 팩에서는 평범하고 오리파에서는
/// 과장되어 보인다. 등급을 네 단계로만 압축해 모든 공개 화면이 같은 신호를 사용하게 한다.
enum RevealEmphasis: Int, Comparable, Sendable {
    case none
    case rare
    case premium
    case apex

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct RevealMotionProfile: Equatable, Sendable {
    let emphasis: RevealEmphasis
    /// 클릭으로 넘길 때 다음 카드가 오기 전 신호를 보여 주는 시간.
    let clickLeadMilliseconds: Int
    let burstStrength: Double

    static func forCard(_ card: PulledCard) -> Self {
        switch card.tier {
        case .energy, .common, .uncommon:
            return Self(emphasis: .none, clickLeadMilliseconds: 0, burstStrength: 0)
        case .rare, .promo, .doubleRare:
            return Self(emphasis: .rare, clickLeadMilliseconds: 90, burstStrength: 0.42)
        case .tripleRare, .prismStar, .amazing, .radiant, .characterRare, .artRare:
            return Self(emphasis: .premium, clickLeadMilliseconds: 135, burstStrength: 0.68)
        case .aceSpec, .superRare, .shiny, .shinyUltra, .specialArtRare, .shining,
             .hyperRare, .ultraRare, .blackWhiteRare, .megaAttack, .megaUltraRare,
             .futureUltra:
            return Self(emphasis: .apex, clickLeadMilliseconds: 190, burstStrength: 1)
        }
    }
}

enum RevealAdvanceKind: Sendable {
    case tap
    case drag
}

/// 카드 면을 하얗게 덮지 않고, 카드 바깥에서만 터지는 희귀도 신호.
/// 홀로그램은 카드의 물성이고 이 효과는 발견 순간의 피드백이므로 서로 섞지 않는다.
@MainActor
struct RevealBurst: View {
    let card: PulledCard
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var profile: RevealMotionProfile { .forCard(card) }
    private var color: Color { tierColor(card.tier) }
    private var height: CGFloat { (width / 0.717).rounded() }
    private var rayCount: Int {
        switch profile.emphasis {
        case .none: return 0
        case .rare: return 8
        case .premium: return 12
        case .apex: return 16
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.075)
                .stroke(color.opacity(0.78), lineWidth: max(2, width * 0.018))
                .blur(radius: width * 0.055)
                .scaleEffect(expanded ? 1.08 : 0.96)

            ForEach(0..<rayCount, id: \.self) { ray in
                Capsule()
                    .fill(color.opacity(ray.isMultiple(of: 2) ? 0.9 : 0.55))
                    .frame(width: max(2, width * 0.012),
                           height: width * (ray.isMultiple(of: 3) ? 0.20 : 0.13))
                    .offset(y: -height * 0.59)
                    .rotationEffect(.degrees(Double(ray) * 360 / Double(max(1, rayCount))))
            }
            .scaleEffect(expanded ? 1 : 0.72)
        }
        .frame(width: width, height: height)
        .opacity(expanded ? profile.burstStrength : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                expanded = true
            } else {
                withAnimation(.easeOut(duration: 0.34)) { expanded = true }
            }
        }
    }
}

/// 특수팩을 카드보다 먼저 폭로하지 않고, 해당 팩의 첫 카드가 착지한 뒤에만 보여 주는 표식.
@MainActor
struct SpecialPackDiscovery: View {
    let title: String
    let hint: String
    let variant: PackVariant

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private var accent: Color {
        switch variant {
        case .scarletViolet151Demigod: return .red
        case .prismaticEvolutionsGod, .prismaticEvolutionsDemigod: return .pink
        case .blackBoltWhiteFlareGod: return Color(white: 0.92)
        case .ascendedHeroesGod: return .purple
        case .standard, .celebrations: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(variant == .blackBoltWhiteFlareGod ? Color.black : Color.white)
            if !hint.isEmpty {
                Text(hint)
                    .font(Typography.labelSemibold)
                    .foregroundStyle(variant == .blackBoltWhiteFlareGod
                                     ? Color.black.opacity(0.78) : Color.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(accent.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
        }
        .shadow(color: accent.opacity(0.72), radius: 24)
        .scaleEffect(visible ? 1 : (reduceMotion ? 1 : 0.72))
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.66)) { visible = true }
            }
        }
    }
}
