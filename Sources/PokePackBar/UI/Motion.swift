import SwiftUI

/// 화면 전체가 같은 박자로 움직이게 하는 공용 동작.
///
/// 화면마다 임의로 시간과 곡선을 정하면 같은 종류의 움직임이 곳마다 다르게 느껴진다.
/// 자주 쓰는 곳(호버, 탭, 숫자)은 짧게, 가끔 있는 순간(구매, 보상)만 길게 둔다.
/// 동작 줄이기가 켜져 있으면 위치와 크기는 움직이지 않고 투명도만 바뀐다.
enum Motion {
    /// 호버와 누름처럼 손에 바로 붙어야 하는 반응.
    static let hover = Animation.easeOut(duration: 0.12)
    /// 숫자가 굴러가며 바뀌는 속도. 매분 바뀌는 잔액도 거슬리지 않을 만큼 짧다.
    static let number = Animation.snappy(duration: 0.35)
    /// 한 화면 안에서 자리가 옮겨 가는 것(탭 선택 표시, 화면 이동).
    static let shift = Animation.snappy(duration: 0.22)
    /// 숫자 배지가 톡 튀는 것. 아주 조금만 넘친다.
    static let bump = Animation.spring(response: 0.28, dampingFraction: 0.55)
}

// MARK: - 호버

/// 누를 수 있는 칸(팩, 카드)에 마우스를 올리면 살짝 떠오른다. 손이 닿기 전에 누를 수 있는
/// 것임을 알린다. macOS 에서는 호버 반응이 없으면 눌러지는 칸인지 알기 어렵다.
@MainActor
private struct HoverLift: ViewModifier {
    let scale: CGFloat
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? scale : 1)
            .shadow(color: .black.opacity(hovering ? 0.22 : 0), radius: hovering ? 7 : 0, y: hovering ? 3 : 0)
            .brightness(hovering ? 0.025 : 0)
            .onHover { hovering = $0 }
            .animation(Motion.hover, value: hovering)
    }
}

/// 줄(시대, 도감, 쿠폰, 가진 팩)에 마우스를 올리면 바탕이 조금 짙어진다. 폭을 다 쓰는 줄은
/// 떠오르게 하면 옆 여백 밖으로 넘치므로 색만 바꾼다.
@MainActor
private struct HoverHighlight: ViewModifier {
    let cornerRadius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0))
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
            .animation(Motion.hover, value: hovering)
    }
}

// MARK: - 숫자

/// 숫자가 바뀌면 한 번 톡 튄다. 팩 수나 알림 수처럼 「늘었다」 는 것을 알아채야 하는 배지에 쓴다.
@MainActor
private struct BumpOnChange<Value: Equatable>: ViewModifier {
    let value: Value
    @State private var bumped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(bumped ? 1.18 : 1)
            .onChange(of: value) {
                guard !reduceMotion else { return }
                withAnimation(Motion.bump) { bumped = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(140))
                    withAnimation(Motion.bump) { bumped = false }
                }
            }
    }
}

/// 값이 처음부터 세어 올라가며 그려지는 글자. 결과 화면의 총 가치처럼 「얼마가 나왔나」 를
/// 기다리게 하는 자리에서만 쓴다. 자주 바뀌는 숫자는 `rollingNumber` 를 쓴다.
@MainActor
struct CountingText: View, @MainActor Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.03) -> some View {
        modifier(HoverLift(scale: scale))
    }

    func hoverHighlight(cornerRadius: CGFloat = 8) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }

    /// 숫자 글자가 바뀔 때 자릿수가 굴러가며 바뀐다.
    func rollingNumber<Value: Equatable>(_ value: Value) -> some View {
        contentTransition(.numericText())
            .animation(Motion.number, value: value)
    }

    func bumpOnChange<Value: Equatable>(_ value: Value) -> some View {
        modifier(BumpOnChange(value: value))
    }
}

// MARK: - 화면 이동

/// 한 단계 들어가고 나오는 화면 전환. 들어갈 때는 오른쪽에서 조금 밀려 들어오고, 나올 때는
/// 왼쪽에서 들어온다. 팝오버는 자주 여닫는 곳이라 거리를 짧게(18pt) 잡는다.
extension AnyTransition {
    static func screen(forward: Bool, reduceMotion: Bool = false) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: forward ? 18 : -18)),
                           removal: .opacity)
    }
}

// MARK: - 누른 자리에서 열기

/// 누른 칸 자리에서 커지며 열리고, 닫으면 그 자리로 줄어드는 화면.
/// 어느 칸을 열었는지가 눈에 이어져, 닫았을 때 어디로 돌아왔는지 찾지 않는다.
extension AnyTransition {
    /// 동작 줄이기가 켜져 있으면 커지지 않고 겹쳐 바뀐다.
    static func zoom(from anchor: UnitPoint, reduceMotion: Bool = false) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .scale(scale: 0.3, anchor: anchor).combined(with: .opacity)
    }
}

/// 누른 자리. 버튼의 접근성과 키보드 동작은 그대로 두고 마우스 위치만 함께 받는다.
/// 키보드로 열면 자리가 없으므로 가운데에서 연다.
struct ZoomOrigin {
    private var point: CGPoint?
    private(set) var anchor = UnitPoint.center

    mutating func record(_ location: CGPoint) { point = location }

    /// 버튼 동작에서 부른다. 같은 클릭의 위치 기록이 먼저 끝나도록 한 박자 뒤에 쓴다.
    mutating func consume(in size: CGSize) {
        if let point, size.width > 0, size.height > 0 {
            anchor = UnitPoint(x: min(1, max(0, point.x / size.width)),
                               y: min(1, max(0, point.y / size.height)))
        } else {
            anchor = .center
        }
        point = nil
    }
}

extension View {
    func recordsClick(in space: String, into origin: Binding<ZoomOrigin>) -> some View {
        simultaneousGesture(SpatialTapGesture(coordinateSpace: .named(space)).onEnded {
            origin.wrappedValue.record($0.location)
        })
    }
}

// MARK: - 팝오버가 보이는가

/// 팝오버가 지금 보이는가. 닫혀도 화면 트리가 남으므로 끝없이 도는 그림은 이 값을 보고 멈춘다.
/// `PopoverNavigation` 이 없는 창(온라인 창, 진단)에서도 읽을 수 있게 환경 값으로 내린다.
private struct PopoverShownKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var popoverShown: Bool {
        get { self[PopoverShownKey.self] }
        set { self[PopoverShownKey.self] = newValue }
    }
}
