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

    init(emphasis: RevealEmphasis) {
        self.emphasis = emphasis
        switch emphasis {
        case .none: (clickLeadMilliseconds, burstStrength) = (0, 0)
        case .rare: (clickLeadMilliseconds, burstStrength) = (90, 0.42)
        case .premium: (clickLeadMilliseconds, burstStrength) = (135, 0.68)
        case .apex: (clickLeadMilliseconds, burstStrength) = (190, 1)
        }
    }

    /// 등급과 시세 중 높은 쪽. 등급으로 정한 연출을 시세가 낮추지는 않는다.
    @MainActor
    static func forCard(_ card: PulledCard) -> Self {
        Self(emphasis: max(tierEmphasis(card.tier), RevealValueEmphasis.emphasis(for: card)))
    }

    static func tierEmphasis(_ tier: CardTier) -> RevealEmphasis {
        switch tier {
        case .energy, .common, .uncommon:
            return .none
        case .rare, .promo, .doubleRare:
            return .rare
        case .tripleRare, .prismStar, .amazing, .radiant, .characterRare, .artRare:
            return .premium
        case .aceSpec, .superRare, .shiny, .shinyUltra, .specialArtRare, .shining,
             .hyperRare, .ultraRare, .blackWhiteRare, .megaAttack, .megaUltraRare,
             .futureUltra:
            return .apex
        }
    }
}

/// 등급만으로는 옛 카드의 무게를 못 잰다. 1999년 베이스 리자몽은 RR 이지만 시세가
/// 최신 SAR 보다 훨씬 높다. 시세(인기의 대리 지표)와 그 팩 안에서의 순위로 연출을 끌어올린다.
@MainActor
enum RevealValueEmphasis {
    static let apexUSD = 100.0
    static let premiumUSD = 25.0
    static let rareUSD = 6.0
    /// 세트 안 시세 상위 2%(최소 1장)는 그 팩의 간판 카드로 본다. 값이 너무 낮은 세트의
    /// 간판까지 띄우지 않도록 바닥 시세를 둔다.
    static let chaseShare = 0.02
    /// 시세 덕에 등급보다 높게 뜬 카드의 빛. 후광과 아우라가 같은 색을 쓴다.
    static let color = Color(red: 1.0, green: 0.80, blue: 0.32)
    static let chaseFloorUSD = 3.0
    private static var chaseThresholds: [String: Double] = [:]
    private static var chasePriceDigest: String?

    static func emphasis(for card: PulledCard,
                         prices: CardPrices? = CardPrices.shared) -> RevealEmphasis {
        guard let prices, card.tier != .energy, !card.isSupplementalEnergy else { return .none }
        let usd = MarketEconomy.usd(cardID: card.id, finish: card.finish, prices: prices)
        var result: RevealEmphasis = usd >= apexUSD ? .apex
            : usd >= premiumUSD ? .premium
            : usd >= rareUSD ? .rare : .none
        if usd >= chaseFloorUSD, let threshold = chaseThreshold(for: card.id, prices: prices),
           usd >= threshold {
            result = max(result, .premium)
        }
        return result
    }

    /// 세트별로 한 번만 센다. 팩을 열 때마다 세트 전체 시세를 다시 훑지 않는다.
    private static func chaseThreshold(for cardID: String, prices: CardPrices) -> Double? {
        if chasePriceDigest != prices.snapshotDigest {
            chaseThresholds.removeAll(keepingCapacity: true)
            chasePriceDigest = prices.snapshotDigest
        }
        guard let index = CardIndex.shared else { return nil }
        let setID = index.card(cardID)?.setID ?? String(cardID.prefix { $0 != "-" })
        if let cached = chaseThresholds[setID] { return cached }
        let values = index.cards(inSet: setID)
            .map { MarketEconomy.usd(cardID: $0, prices: prices) }
            .sorted(by: >)
        guard !values.isEmpty else { return nil }
        let count = max(1, Int((Double(values.count) * chaseShare).rounded(.up)))
        let threshold = values[min(count, values.count) - 1]
        chaseThresholds[setID] = threshold
        return threshold
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

/// 희귀한 장에서 계속 뿜어져 나오는 기운.
///
/// 한 번 터지고 끝나는 신호가 아니라 그 장이 보이는 동안 이어진다. 등급 색의 파동이 카드
/// 테두리에서 바깥으로 퍼지며 사라지고, 최상위 등급은 빛줄기가 천천히 돈다. 위상은 시계에서
/// 바로 구하므로 다음 장의 기운이 현재 장의 기운으로 바뀌어도 박자가 끊기지 않는다.
@MainActor
struct RevealAura: View {
    let card: PulledCard
    let width: CGFloat
    /// 매 프레임 시세를 다시 찾지 않도록 만들 때 한 번 정한다.
    private let emphasis: RevealEmphasis
    private let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(card: PulledCard, width: CGFloat) {
        self.card = card
        self.width = width
        let emphasis = RevealMotionProfile.forCard(card).emphasis
        self.emphasis = emphasis
        // 시세 덕에 등급보다 높게 뜬 카드는 금빛으로 뿜는다. 등급 색 그대로면 옛 RR 홀로가
        // 평범한 레어처럼 보인다.
        self.color = emphasis > RevealMotionProfile.tierEmphasis(card.tier)
            ? RevealValueEmphasis.color
            : tierColor(card.tier)
    }
    private var height: CGFloat { (width / 0.717).rounded() }
    /// 카드 바깥으로 퍼질 자리까지 포함한 캔버스.
    private var canvasSize: CGSize { CGSize(width: width * 1.7, height: height * 1.5) }

    private var strength: Double {
        switch emphasis {
        case .none: return 0
        case .rare: return 0.45
        case .premium: return 0.72
        case .apex: return 1
        }
    }
    /// 파동 하나가 퍼져 사라지는 시간. 귀할수록 빠르게 뿜는다.
    private var period: Double {
        switch emphasis {
        case .none, .rare: return 1.7
        case .premium: return 1.35
        case .apex: return 1.05
        }
    }
    private var waveCount: Int { emphasis == .apex ? 3 : 2 }

    var body: some View {
        Group {
            if emphasis == .none {
                EmptyView()
            } else if reduceMotion {
                Canvas { context, size in draw(context, size: size, time: 0.3 * period) }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        draw(context, size: size,
                             time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .blur(radius: width * 0.018)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for wave in 0..<waveCount {
            var phase = time / period + Double(wave) / Double(waveCount)
            phase -= floor(phase)
            // 테두리에 붙어 시작해 바깥으로 퍼지며 옅어진다.
            let grow = 0.99 + phase * 0.30
            let rect = CGRect(x: center.x - width * grow / 2, y: center.y - height * grow / 2,
                              width: width * grow, height: height * grow)
            let path = Path(roundedRect: rect, cornerRadius: width * 0.06 * grow)
            let fade = pow(1 - phase, 1.6)
            context.stroke(path, with: .color(color.opacity(strength * 0.85 * fade)),
                           lineWidth: max(1.5, width * (0.032 - 0.02 * phase)))
        }
        guard emphasis == .apex else { return }
        // 최상위 등급: 카드 둘레에서 뻗는 빛줄기가 천천히 돌며 깜빡인다.
        let rays = 14
        let spin = time * 0.35
        let reach = max(width, height) * 0.62
        for ray in 0..<rays {
            let angle = spin + Double(ray) * 2 * .pi / Double(rays)
            let flicker = 0.55 + 0.45 * sin(time * 3.1 + Double(ray) * 1.7)
            let inner = reach * 0.80, outer = reach * (0.93 + 0.07 * flicker)
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            context.stroke(path, with: .color(color.opacity(0.55 * flicker)),
                           style: StrokeStyle(lineWidth: max(1.5, width * 0.012), lineCap: .round))
        }
    }
}

/// 누르는 순간 다음 장이 희귀하면 카드 둘레에서 팡 튀는 불꽃.
///
/// 아우라는 장이 바뀌어도 이어지므로 희귀한 장 다음에 또 희귀한 장이 오면 구분이 안 됐다.
/// 이 신호는 누를 때마다 새로 터지고 혼자 사라지므로 카드 넘김을 붙잡지 않는다.
@MainActor
struct RevealPop: View {
    let card: PulledCard
    let width: CGFloat
    private let emphasis: RevealEmphasis
    private let color: Color

    @State private var progress = 0.0

    init(card: PulledCard, width: CGFloat) {
        self.card = card
        self.width = width
        let emphasis = RevealMotionProfile.forCard(card).emphasis
        self.emphasis = emphasis
        self.color = emphasis > RevealMotionProfile.tierEmphasis(card.tier)
            ? RevealValueEmphasis.color
            : tierColor(card.tier)
    }

    private var height: CGFloat { (width / 0.717).rounded() }
    private var sparkCount: Int {
        switch emphasis {
        case .none: return 0
        case .rare: return 10
        case .premium: return 16
        case .apex: return 24
        }
    }

    var body: some View {
        // Canvas 안에서만 쓰는 값은 SwiftUI 가 보간하지 않는다 — withAnimation 이 0 에서 곧장
        // 1(다 사라진 상태)로 건너뛰어 앱에서는 아무것도 안 보였다. 보간되는 뷰에 진행도를 넘긴다.
        RevealPopCanvas(progress: progress, seedSource: card.id, width: width, height: height,
                        sparkCount: sparkCount, color: color)
            .frame(width: width * 1.9, height: height * 1.6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { withAnimation(.easeOut(duration: 0.55)) { progress = 1 } }
    }
}

/// 진행도를 animatableData 로 받아 매 프레임 다시 그린다.
@MainActor
private struct RevealPopCanvas: View, @MainActor Animatable {
    var progress: Double
    let seedSource: String
    let width: CGFloat
    let height: CGFloat
    let sparkCount: Int
    let color: Color

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let progress = self.progress
        return Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let fade = 1 - progress
            // 테두리 빛 고리가 한 번 번쩍이며 벌어진다.
            let ring = 1 + progress * 0.10
            let rect = CGRect(x: center.x - width * ring / 2, y: center.y - height * ring / 2,
                              width: width * ring, height: height * ring)
            context.stroke(Path(roundedRect: rect, cornerRadius: width * 0.06 * ring),
                           with: .color(color.opacity(0.9 * pow(fade, 2))),
                           lineWidth: max(2, width * 0.022))
            var seed = UInt64(truncatingIfNeeded: seedSource.hashValue) | 1
            func random() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 11) / Double(UInt64.max >> 11)
            }
            for spark in 0..<sparkCount {
                let angle = (Double(spark) + random() * 0.8) / Double(sparkCount) * 2 * .pi
                let dx = cos(angle), dy = sin(angle)
                // 카드 테두리 위의 출발점에서 바깥으로.
                let edge = min((width / 2) / max(abs(dx), 0.001), (height / 2) / max(abs(dy), 0.001))
                let travel = width * (0.16 + random() * 0.22) * (1 - pow(fade, 3))
                let point = CGPoint(x: center.x + dx * (edge + travel), y: center.y + dy * (edge + travel))
                let radius = max(1.5, width * (0.012 + random() * 0.014)) * (0.6 + 0.4 * fade)
                let dot = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: dot), with: .color(color.opacity(fade)))
                context.fill(Path(ellipseIn: dot.insetBy(dx: radius * 0.45, dy: radius * 0.45)),
                             with: .color(.white.opacity(0.9 * fade)))
            }
        }
    }
}
