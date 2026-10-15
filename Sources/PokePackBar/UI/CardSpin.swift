import AppKit
import SwiftUI

// MARK: - 드래그로 돌리기

/// 카드를 끌어 돌린 자세.
///
/// 좌우로 끌면 세로축으로 끝까지 돈다(`yaw`, 0 이 앞면, 180 이 뒷면). 위아래로 끌면
/// 가로축으로 조금만 기울었다가 놓으면 돌아온다(`pitch`). 두 축을 다 끝까지 돌리면 앞면이
/// 거꾸로 멈추거나, 뒷면일 때 위아래 방향이 손과 반대로 도는 자세가 생긴다. 실물 카드를
/// 손가락으로 돌려 보는 것처럼 한 축만 끝까지 돌린다.
struct CardSpin: Equatable {
    /// 세로축으로 돌린 각도(도). 끝없이 늘어날 수 있다.
    var yaw: Double
    /// 가로축으로 기운 각도(도). 아래로 끌수록 아래쪽이 멀어진다.
    var pitch: Double

    static let rest = CardSpin(yaw: 0, pitch: 0)

    /// 위아래로 기울일 수 있는 한계. 이보다 더 끌어도 그 자리에 머문다.
    static let pitchLimit = 35.0

    /// 앞면이 보는 사람 쪽인지. 앞면의 법선은 cos(yaw) * cos(pitch) 만큼 화면을 향하고,
    /// `pitch` 는 90도에 못 미치므로 `yaw` 만 보면 된다.
    var showsFront: Bool { cos(yaw * .pi / 180) >= 0 }

    /// 앞면이나 뒷면을 똑바로 보고 멈춘 자세인지. 이때만 마우스 위치로 기울인다.
    var isSettled: Bool {
        abs(yaw - (yaw / 180).rounded() * 180) < 0.01 && abs(pitch) < 0.01
    }

    /// 끈 거리만큼 돌린 자세. 카드 폭만큼 끌면 반 바퀴다.
    func turned(by translation: CGSize, width: CGFloat) -> CardSpin {
        let degreesPerPoint = 180 / Double(max(width, 1))
        let pitch = Double(translation.height) * degreesPerPoint
        return CardSpin(yaw: yaw + Double(translation.width) * degreesPerPoint,
                        pitch: min(Self.pitchLimit, max(-Self.pitchLimit, pitch)))
    }

    /// 놓았을 때 멈출 자세: 가장 가까운 앞면이나 뒷면, 기울기는 0.
    var settled: CardSpin { CardSpin(yaw: (yaw / 180).rounded() * 180, pitch: 0) }

    /// 가장 가까운 앞면.
    var front: CardSpin { CardSpin(yaw: (yaw / 360).rounded() * 360, pitch: 0) }

    /// 도는 동안 광택이 따라 흐르게 카드 본체에 넘길 기울기.
    ///
    /// 카드 본체는 이 값으로 빛을 옮기면서 몸체도 조금 더 기울인다. 좌우 값을 sin(2 * yaw) 로
    /// 두면 앞면이 옆으로 설 때(±90도) 0 이 되어, 더 기운 앞면의 뒤쪽이 비치지 않는다.
    var lightTilt: TiltVector {
        let pitchShare = sin(pitch * .pi / 180) / sin(Self.pitchLimit * .pi / 180)
        return TiltVector(nx: sin(2 * yaw * .pi / 180) * 0.9, ny: pitchShare * 0.9)
    }
}

/// 돌리는 카드의 무대. 애니메이션 중간 각도마다 다시 그려, 옆으로 서는 순간 앞면과 뒷면을
/// 바꿔 낀다. 상태 값만 보고 고르면 놓는 순간 끝 각도의 면이 먼저 보인다.
@MainActor
struct CardSpinStage<Front: View>: View, @MainActor Animatable {
    var spin: CardSpin
    /// 앞면을 똑바로 보고 멈췄을 때 쓸 마우스 기울기. 끄는 동안에는 nil 이다.
    let pointerTilt: TiltVector?
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let front: (TiltVector) -> Front

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(spin.yaw, spin.pitch) }
        set { spin = CardSpin(yaw: newValue.first, pitch: newValue.second) }
    }

    var body: some View {
        let facingFront = spin.showsFront
        ZStack {
            if facingFront {
                front(spin.isSettled ? pointerTilt ?? .zero : spin.lightTilt)
            } else {
                // 뒷면은 앞면의 반대쪽에 붙어 있다. 미리 반 바퀴 돌려 두어야 반 바퀴 돌았을 때
                // 글자가 바로 읽힌다.
                CardBackFace(width: width, height: height)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(spin.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(spin.pitch), axis: (x: -1, y: 0, z: 0), perspective: 0.45)
    }
}

/// 카드 뒷면. 리소스의 `card-back` 그림을 쓰고, 없으면 같은 비율의 어두운 판으로 대신한다.
@MainActor
struct CardBackFace: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let corner = width * 0.05
        Group {
            if let image = CardBackImage.image {
                Image(nsImage: image).resizable().interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.12, green: 0.2, blue: 0.45),
                                        Color(red: 0.05, green: 0.08, blue: 0.22)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: width * 0.045, y: width * 0.022)
        .accessibilityHidden(true)
    }
}

/// 뒷면 그림은 한 장뿐이라 처음 한 번만 읽는다.
enum CardBackImage {
    static let image: NSImage? = AppResources.bundle?
        .url(forResource: "card-back", withExtension: "webp")
        .flatMap(NSImage.init(contentsOf:))
}
