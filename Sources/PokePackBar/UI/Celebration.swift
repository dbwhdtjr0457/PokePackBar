import SwiftUI

/// 무엇을 받은 순간의 반짝임. 한 번 터져 퍼지며 사라진다.
///
/// 받는 순간(도감 보상, 일괄 판매)에 아무 반응이 없으면 눌렀는데 된 건지 화면을 다시
/// 읽어야 안다. 흐림(blur) 없이 작은 별만 그려 가볍다. 동작 줄이기가 켜져 있으면 그리지 않는다.
@MainActor
struct SparkBurst: View {
    let color: Color
    var count = 14
    var radius: CGFloat = 48
    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SparkBurstCanvas(progress: progress, color: color, count: count, radius: radius)
            .frame(width: radius * 3, height: radius * 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
            }
    }
}

@MainActor
private struct SparkBurstCanvas: View, @MainActor Animatable {
    var progress: Double
    let color: Color
    let count: Int
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0, progress < 1 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // 빠르게 튀어 나갔다가 느려지고, 끝에서 살짝 떨어진다.
            let travel = 1 - pow(1 - progress, 3)
            let alpha = progress < 0.55 ? 1 : (1 - progress) / 0.45
            for index in 0..<count {
                let angle = Double(index) / Double(count) * 2 * .pi + (index.isMultiple(of: 2) ? 0.14 : -0.1)
                let reach = Double(radius) * (0.55 + 0.45 * Double((index * 37) % 10) / 10)
                let point = CGPoint(x: center.x + cos(angle) * reach * travel,
                                    y: center.y + sin(angle) * reach * travel + 12 * progress * progress)
                let size = (index % 3 == 0 ? 4.6 : 3.1) * (1 - 0.55 * progress)
                context.fill(Self.star(at: point, size: size),
                             with: .color((index % 4 == 0 ? Color.white : color).opacity(alpha)))
            }
        }
    }

    /// 네 갈래 별.
    private static func star(at point: CGPoint, size: Double) -> Path {
        var path = Path()
        let inner = size * 0.32
        for step in 0..<8 {
            let angle = Double(step) * .pi / 4 - .pi / 2
            let length = step.isMultiple(of: 2) ? size : inner
            let vertex = CGPoint(x: point.x + cos(angle) * length, y: point.y + sin(angle) * length)
            if step == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        return path
    }
}

/// 도감 보상을 받았다는 알림. 받은 것을 도감 화면과 같은 칩으로 적는다.
struct RewardNotice: Identifiable, Equatable {
    let id = UUID()
    let reward: DexReward
    let homeSet: String
}

/// 반짝임이 터질 자리(팝오버 좌표).
struct SparkEvent: Identifiable, Equatable {
    let id = UUID()
    let center: CGPoint
    let color: Color
}

/// 팝오버 맨 위에 겹쳐 그리는 축하 층. 손을 가로막지 않는다.
@MainActor
struct CelebrationLayer: View {
    let wallet: WalletStore
    @Environment(PopoverNavigation.self) private var nav

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(nav.sparks) { spark in
                SparkBurst(color: spark.color)
                    .position(spark.center)
                    .task {
                        try? await Task.sleep(for: .seconds(0.9))
                        nav.sparks.removeAll { $0.id == spark.id }
                    }
            }
            if let notice = nav.rewardNotice {
                RewardNoticeBanner(wallet: wallet, notice: notice)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(notice.id)
                    .task {
                        try? await Task.sleep(for: .seconds(2.8))
                        guard nav.rewardNotice?.id == notice.id else { return }
                        withAnimation(.snappy(duration: 0.3)) { nav.rewardNotice = nil }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

@MainActor
private struct RewardNoticeBanner: View {
    let wallet: WalletStore
    let notice: RewardNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(wallet.l.dexRewardReceived, systemImage: "gift.fill")
                .font(Typography.bodySemibold)
                .foregroundStyle(Color.accentColor)
            DexRewardLine(wallet: wallet, index: CardIndex.shared, reward: notice.reward,
                          homeSet: notice.homeSet)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}

extension PopoverNavigation {
    /// 도감 보상을 받은 순간. 알림을 띄우고, 버튼 자리에서 반짝이고, 팩이면 팩 탭으로 날린다.
    func celebrate(_ claim: DexClaim, from origin: CGRect, reduceMotion: Bool) {
        SoundEffects.play(.chime(3))
        withAnimation(.snappy(duration: 0.3)) {
            rewardNotice = RewardNotice(reward: claim.reward, homeSet: claim.dex.homeSet)
        }
        guard origin != .zero else { return }
        if !reduceMotion {
            sparks.append(SparkEvent(center: CGPoint(x: origin.midX, y: origin.midY), color: .yellow))
        }
        guard claim.reward.packs > 0 else { return }
        if reduceMotion {
            packArrivals += 1
            return
        }
        let art = CGRect(x: origin.midX - 17, y: origin.midY - 31, width: 34, height: 62)
        packFlights += (0..<min(claim.reward.packs, PackFlight.maximumShown)).map {
            PackFlight(setID: claim.dex.homeSet, origin: art, delay: 0.15 + Double($0) * 0.09)
        }
    }
}
