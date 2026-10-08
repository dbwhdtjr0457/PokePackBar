import SwiftUI

/// 상점에서 산 팩이 팩 탭으로 날아가는 그림 한 장.
///
/// 사기만 하고 아무것도 움직이지 않으면 산 팩이 어디로 갔는지 알 수 없다. 팩 그림이 탭
/// 줄의 「팩」 칸으로 날아가 내려앉고, 그 칸이 톡 튀면 다음에 무엇을 할지가 보인다.
struct PackFlight: Identifiable, Equatable {
    let id = UUID()
    let setID: String
    /// 출발 자리. 팝오버 전체 좌표(`PackFlight.space`)다.
    let origin: CGRect
    /// 여러 팩을 샀을 때 차례로 날리는 간격.
    let delay: Double

    static let space = "popover"
    /// 한 번에 날리는 그림 수. 10팩을 사도 세 장만 날린다 — 그 이상은 하늘이 어지럽다.
    static let maximumShown = 3
}

/// 날고 있는 팩들. 팝오버 맨 위에 겹쳐 그리고, 손을 가로막지 않는다.
@MainActor
struct PackFlightLayer: View {
    let flights: [PackFlight]
    let target: CGPoint
    let onArrive: (PackFlight) -> Void

    var body: some View {
        ZStack {
            ForEach(flights) { flight in
                PackFlightRunner(flight: flight, target: target, onArrive: onArrive)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private struct PackFlightRunner: View {
    let flight: PackFlight
    let target: CGPoint
    let onArrive: (PackFlight) -> Void
    @State private var progress = 0.0

    var body: some View {
        PackFlightSprite(setID: flight.setID, origin: flight.origin, target: target, progress: progress)
            .task {
                try? await Task.sleep(for: .seconds(flight.delay))
                guard !Task.isCancelled else { return }
                withAnimation(.timingCurve(0.35, 0, 0.25, 1, duration: 0.62)) {
                    progress = 1
                } completion: {
                    onArrive(flight)
                }
            }
    }
}

/// 출발점에서 위로 한 번 떴다가 탭 칸으로 내려앉는 곡선. 직선으로 가면 미끄러지는
/// 것처럼 보여 「던졌다」 는 느낌이 없다.
@MainActor
private struct PackFlightSprite: View, @MainActor Animatable {
    let setID: String
    let origin: CGRect
    let target: CGPoint
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let t = progress
        let start = CGPoint(x: origin.midX, y: origin.midY)
        let control = CGPoint(x: (start.x + target.x) / 2, y: min(start.y, target.y) - 70)
        let u = 1 - t
        let x = u * u * start.x + 2 * u * t * control.x + t * t * target.x
        let y = u * u * start.y + 2 * u * t * control.y + t * t * target.y
        // 끝에서 탭 칸에 빨려 들어가듯 작아지고, 닿는 순간 사라진다.
        let fade = t < 0.82 ? 1 : max(0, (1 - t) / 0.18)
        return PackImageView(setID: setID, width: origin.width)
            .shadow(color: .black.opacity(0.28 * fade), radius: 6, y: 3)
            .scaleEffect(1 - 0.72 * t)
            .rotationEffect(.degrees(-14 * t))
            .opacity(t == 0 ? 0 : fade)
            .position(x: x, y: y)
    }
}
