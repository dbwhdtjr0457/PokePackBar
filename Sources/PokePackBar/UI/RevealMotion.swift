import SwiftUI

/// 카드 공개 연출의 한 가지 기준점.
///
/// 화면마다 임의로 지연과 빛의 세기를 정하면 같은 카드가 팩에서는 평범하고 오리파에서는
/// 과장되어 보인다. 다섯 단계로만 압축해 모든 공개 화면이 같은 신호를 사용하게 한다.
///
/// 단계는 **그 팩에서 얼마나 드물게 나오는가**로 정한다(`PullRarity`). 등급 이름으로 정하면
/// 거의 매 팩 나오는 R 에도 불꽃이 터진다.
enum RevealEmphasis: Int, Comparable, Sendable {
    case none
    case rare
    case premium
    case apex
    /// 150팩에 한 번보다 드문 카드. 빛이 무지개로 돌고 소리도 따로 난다 — 아래 단계와
    /// 세기만 다르면 「정말 귀한 것」이 「꽤 좋은 것」과 구분되지 않는다.
    case mythic

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
        case .mythic: (clickLeadMilliseconds, burstStrength) = (260, 1)
        }
    }

    /// 드묾과 시세 중 높은 쪽. 드묾으로 정한 연출을 시세가 낮추지는 않는다.
    @MainActor
    static func forCard(_ card: PulledCard) -> Self {
        Self(emphasis: max(rarityEmphasis(card), RevealValueEmphasis.emphasis(for: card)))
    }

    /// 그 카드의 등급이 제 세트 팩에서 몇 팩에 한 번 나오는가로 정한 단계.
    /// 팩에서 나오지 않는 등급(프로모 등)은 등급 이름으로 정하되 가장 높은 단계는 주지 않는다.
    static func rarityEmphasis(_ card: PulledCard) -> RevealEmphasis {
        guard card.tier != .energy, !card.isSupplementalEnergy else { return .none }
        let setID = CardIndex.shared?.card(card.id)?.setID ?? String(card.id.prefix { $0 != "-" })
        if let packs = PullRarity.packsPerPull(setID: setID, tier: card.tier) {
            return PullRarity.emphasis(packsPerPull: packs)
        }
        return tierEmphasis(card.tier)
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

extension RevealEmphasis {
    /// 이 단계에서 나는 소리. 평범한 카드는 소리가 없고, 가장 높은 단계는 종소리 대신
    /// 두 옥타브를 오르는 팡파르를 낸다.
    @MainActor
    var sound: SoundEffects.Effect? {
        switch self {
        case .none: nil
        case .rare: .chime(1)
        case .premium: .chime(2)
        case .apex: .chime(4)
        case .mythic: .fanfare
        }
    }

    /// 가장 높은 단계는 한 가지 등급 색 대신 무지개로 돈다.
    var isPrismatic: Bool { self == .mythic }

    /// 무지개 단계에서 각도(0~1)마다 쓰는 색. 시간이 흐르면 색이 돌아간다.
    static func prismColor(_ position: Double, time: Double = 0) -> Color {
        var hue = position + time * 0.12
        hue -= floor(hue)
        return Color(hue: hue, saturation: 0.62, brightness: 1)
    }
}

/// 등급만으로는 옛 카드의 무게를 못 잰다. 1999년 베이스 리자몽은 RR 이지만 시세가
/// 최신 SAR 보다 훨씬 높다. 시세(인기의 대리 지표)와 그 팩 안에서의 순위로 연출을 끌어올린다.
@MainActor
enum RevealValueEmphasis {
    // 문턱을 높게 둔다. 낮으면 흔한 카드가 시세 몇 달러로 불꽃을 터뜨려, 드묾으로 나눈 단계가
    // 다시 흐려진다. 가장 높은 단계(무지개)는 시세로는 주지 않는다 — 그것은 드묾의 몫이다.
    static let apexUSD = 150.0
    static let premiumUSD = 40.0
    static let rareUSD = 12.0
    /// 세트 안 시세 상위 2%(최소 1장)는 그 팩의 간판 카드로 본다. 값이 너무 낮은 세트의
    /// 간판까지 띄우지 않도록 바닥 시세를 둔다.
    static let chaseShare = 0.02
    /// 시세 덕에 등급보다 높게 뜬 카드의 빛. 후광과 아우라가 같은 색을 쓴다.
    static let color = Color(red: 1.0, green: 0.80, blue: 0.32)
    static let chaseFloorUSD = 12.0
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
        case .mythic: return 28
        }
    }
    private func rayColor(_ ray: Int) -> Color {
        profile.emphasis.isPrismatic
            ? RevealEmphasis.prismColor(Double(ray) / Double(max(1, rayCount)))
            : color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.075)
                .stroke(profile.emphasis.isPrismatic
                            ? AnyShapeStyle(AngularGradient(colors: (0...6).map { RevealEmphasis.prismColor(Double($0) / 6) },
                                                            center: .center))
                            : AnyShapeStyle(color.opacity(0.78)),
                        lineWidth: max(2, width * 0.018))
                .blur(radius: width * 0.055)
                .scaleEffect(expanded ? 1.08 : 0.96)

            ForEach(0..<rayCount, id: \.self) { ray in
                Capsule()
                    .fill(rayColor(ray).opacity(ray.isMultiple(of: 2) ? 0.9 : 0.55))
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
    /// 진단 렌더러가 고정된 순간을 그릴 때만 준다. 실제 화면은 시계를 따른다.
    var clock: Double? = nil
    /// 매 프레임 시세를 다시 찾지 않도록 만들 때 한 번 정한다.
    private let emphasis: RevealEmphasis
    private let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.popoverShown) private var popoverShown

    init(card: PulledCard, width: CGFloat, clock: Double? = nil) {
        self.card = card
        self.width = width
        self.clock = clock
        let emphasis = RevealMotionProfile.forCard(card).emphasis
        self.emphasis = emphasis
        // 시세 덕에 드묾보다 높게 뜬 카드는 금빛으로 뿜는다. 등급 색 그대로면 옛 RR 홀로가
        // 평범한 레어처럼 보인다.
        self.color = emphasis > RevealMotionProfile.rarityEmphasis(card)
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
        case .apex, .mythic: return 1
        }
    }
    /// 파동 하나가 퍼져 사라지는 시간. 귀할수록 빠르게 뿜는다.
    private var period: Double {
        switch emphasis {
        case .none, .rare: return 1.7
        case .premium: return 1.35
        case .apex: return 1.05
        case .mythic: return 0.9
        }
    }
    private var waveCount: Int {
        switch emphasis {
        case .apex: return 3
        case .mythic: return 4
        default: return 2
        }
    }

    var body: some View {
        Group {
            if emphasis == .none {
                EmptyView()
            } else if let clock {
                Canvas { context, size in draw(context, size: size, time: clock) }
            } else if reduceMotion {
                Canvas { context, size in draw(context, size: size, time: 0.3 * period) }
            } else {
                // 초당 30장일 때는 120Hz 화면에서 파동이 계단처럼 끊겼다. 60장으로 그리고,
                // 팝오버가 닫히면 멈춘다 — 닫혀도 화면 트리가 남아 그대로 두면 계속 그린다.
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !popoverShown)) { timeline in
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
        if emphasis >= .apex { drawBeams(context, center: center, time: time) }
        for wave in 0..<waveCount {
            var phase = time / period + Double(wave) / Double(waveCount)
            phase -= floor(phase)
            // 테두리에 붙어 시작해 바깥으로 퍼지며 옅어진다.
            let grow = 0.99 + phase * 0.30
            let rect = CGRect(x: center.x - width * grow / 2, y: center.y - height * grow / 2,
                              width: width * grow, height: height * grow)
            let path = Path(roundedRect: rect, cornerRadius: width * 0.06 * grow)
            let fade = pow(1 - phase, 1.6)
            // 무지개 단계는 파동마다 색이 달라, 퍼져 나가며 색이 바뀌어 보인다.
            let waveColor = emphasis.isPrismatic
                ? RevealEmphasis.prismColor(Double(wave) / Double(waveCount), time: time)
                : color
            context.stroke(path, with: .color(waveColor.opacity(strength * 0.85 * fade)),
                           lineWidth: max(1.5, width * (0.032 - 0.02 * phase)))
        }
    }

    /// 최상위 등급: 카드 뒤에서 뻗어 나오는 빛기둥이 천천히 돌며 숨쉰다. 끝으로 갈수록
    /// 가늘고 옅어져, 짧은 선이 흩어진 것처럼 보이지 않는다. 카드에 가려지는 안쪽은 그리지 않는다.
    private func drawBeams(_ context: GraphicsContext, center: CGPoint, time: Double) {
        // 무지개 단계는 빛기둥이 더 많고 더 빨리 돌며, 기둥마다 색이 다르다.
        let beams = emphasis.isPrismatic ? 18 : 12
        let spin = time * (emphasis.isPrismatic ? 0.34 : 0.22)
        let reach = max(width, height) * 0.74
        let start = min(width, height) * 0.42
        for beam in 0..<beams {
            let angle = spin + Double(beam) * 2 * .pi / Double(beams)
            let breath = 0.6 + 0.4 * sin(time * 2.1 + Double(beam) * 1.7)
            let spread = beam.isMultiple(of: 2) ? 0.075 : 0.05
            let outer = reach * (0.92 + 0.1 * breath)
            func point(_ radius: Double, _ offset: Double) -> CGPoint {
                CGPoint(x: center.x + cos(angle + offset) * radius,
                        y: center.y + sin(angle + offset) * radius)
            }
            var wedge = Path()
            wedge.move(to: point(start, -spread * 0.35))
            wedge.addLine(to: point(outer, -spread))
            wedge.addLine(to: point(outer, spread))
            wedge.addLine(to: point(start, spread * 0.35))
            wedge.closeSubpath()
            let fadeIn = start / outer
            let beamColor = emphasis.isPrismatic
                ? RevealEmphasis.prismColor(Double(beam) / Double(beams), time: time)
                : color
            context.fill(wedge, with: .radialGradient(
                Gradient(stops: [
                    .init(color: beamColor.opacity(0), location: 0),
                    .init(color: beamColor.opacity(0.42 * breath), location: fadeIn + 0.08),
                    .init(color: beamColor.opacity(0.16 * breath), location: 0.72),
                    .init(color: beamColor.opacity(0), location: 1),
                ]),
                center: center, startRadius: 0, endRadius: outer))
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
        self.color = emphasis > RevealMotionProfile.rarityEmphasis(card)
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
        case .mythic: return 40
        }
    }

    var body: some View {
        // Canvas 안에서만 쓰는 값은 SwiftUI 가 보간하지 않는다 — withAnimation 이 0 에서 곧장
        // 1(다 사라진 상태)로 건너뛰어 앱에서는 아무것도 안 보였다. 보간되는 뷰에 진행도를 넘긴다.
        RevealPopCanvas(progress: progress, seedSource: card.id, width: width, height: height,
                        sparkCount: sparkCount, color: color, prismatic: emphasis.isPrismatic)
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
    /// 가장 높은 단계는 불꽃마다 색이 다르다.
    var prismatic = false

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
                           with: prismatic
                               ? .conicGradient(Gradient(colors: (0...6).map { RevealEmphasis.prismColor(Double($0) / 6) }
                                                            .map { $0.opacity(0.9 * pow(fade, 2)) }),
                                                center: center)
                               : .color(color.opacity(0.9 * pow(fade, 2))),
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
                // 보상과 판매의 반짝임과 같은 네 갈래 별. 가운데는 하얗게 빛난다.
                let sparkColor = prismatic
                    ? RevealEmphasis.prismColor(Double(spark) / Double(max(1, sparkCount)))
                    : color
                context.fill(SparkShape.star(at: point, size: radius * 1.9),
                             with: .color(sparkColor.opacity(fade)))
                context.fill(SparkShape.star(at: point, size: radius * 0.95),
                             with: .color(.white.opacity(0.9 * fade)))
            }
        }
    }
}

// MARK: - 진단

/// 희귀 카드의 후광과 기운을 고정된 순간마다 PNG 로 뽑는다. 개봉 화면을 손으로 찍으면
/// 매번 다른 순간이 찍혀 전후를 견줄 수 없다.
@MainActor
enum RevealEffectDiagnostics {
    static func request(from arguments: [String]) -> (cardID: String, output: URL, dark: Bool)? {
        guard let flag = arguments.firstIndex(of: "--render-reveal-effects"),
              arguments.indices.contains(flag + 2) else { return nil }
        return (arguments[flag + 1], URL(fileURLWithPath: arguments[flag + 2], isDirectory: true),
                arguments.contains("--dark"))
    }

    static func render(cardID: String, output: URL, dark: Bool) async throws -> Int {
        guard let entry = CardIndex.shared?.card(cardID) else {
            throw LocalAudit.Failure(description: "Not in the card index: \(cardID)")
        }
        let image = await CardImageLoader.image(cardID: cardID, hires: true)
        let card = PulledCard(id: cardID, tier: entry.tier, isNew: false, finish: .normal)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let width = RevealPeek.cardWidth
        var written = 0
        for frame in 0..<8 {
            let time = Double(frame) * 0.15
            let view = ZStack {
                (dark ? Color(white: 0.16) : Color(white: 0.93))
                ZStack {
                    TierGlow(tier: entry.tier, width: width, valueCard: card, startBloomed: true)
                    RevealAura(card: card, width: width, clock: time)
                    CardImageView(cardID: cardID, hires: true, width: width, preloaded: image)
                }
            }
            .frame(width: width * 1.9, height: (width / 0.717) * 1.6)
            .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let rendered = renderer.nsImage, let tiff = rendered.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw LocalAudit.Failure(description: "Cannot render frame \(frame)")
            }
            try png.write(to: output.appendingPathComponent(String(format: "frame-%02d.png", frame)),
                          options: .atomic)
            written += 1
        }
        return written
    }
}
