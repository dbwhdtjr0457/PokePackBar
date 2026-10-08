import AppKit
import SwiftUI

/// 팩 뜯기. 개봉을 누른 뒤 첫 장이 나오기 전까지의 한 장면이다.
///
/// 서버가 팩을 여는 동안과 카드 그림을 받는 동안을 한 화면으로 잇는다. 예전에는 두 화면이
/// 같은 팩 그림과 스피너만 번갈아 보여 줘서, 정작 팩을 뜯는 순간이 없었다.
///
/// 순서는 봉인, 뜯기, 꺼내기다. 봉인된 팩은 떠서 천천히 흔들리고, 흔들림을 따라 포장지
/// 광택이 오간다. 윗부분을 옆으로 밀면 손을 따라 찢어지고, 누르기만 하면 저절로 찢어진다.
/// 찢긴 띠가 날아가면 카드가 팩에서 올라오고, 팩은 아래로 빠진다.
///
/// **결과를 미리 알리지 않는다.** 갓팩이든 아니든 이 화면의 색, 빛, 진동은 똑같다.
/// 카드는 뜯은 뒤 꺼낼 때 처음 보인다.
///
/// 배치는 `RevealView.current` 와 같은 골격이다(머리글, 카드 자리, 두 줄 안내, 버튼).
/// 그래서 꺼낸 카드가 멈추는 자리가 첫 장이 등장을 시작하는 밑장 자리와 정확히 겹친다.
@MainActor
struct PackTearView: View {
    let wallet: WalletStore
    let setID: String
    let setName: String
    let packCount: Int
    /// 서버가 아직 팩을 여는 중이면 비어 있다. 그동안에도 뜯을 수 있다.
    let pending: PacksView.PendingPack?
    /// 서버가 여는 동안에만 취소할 수 있다. 카드가 들어온 뒤에는 되돌릴 것이 없다.
    let onCancel: (() -> Void)?
    let onReady: (PacksView.OpenedPack) -> Void

    /// 봉인, 찢는 중, 띠가 날아가는 중, 열림(카드 기다림), 꺼내는 중, 넘김.
    private enum Phase { case sealed, tearing, opening, torn, extracting, done }

    @State private var phase = Phase.sealed
    @State private var pose = PackTearPose()
    /// 그림까지 받아 둔 결과. 뜯기와 받기 중 늦게 끝나는 쪽이 꺼내기를 시작한다.
    @State private var loaded: PacksView.OpenedPack?
    @State private var packImage: NSImage?
    @State private var choreography: Task<Void, Never>?
    /// 이번 끌기에서 몇 번째 눈금까지 찢었는가. 눈금마다 한 번씩 짧게 떨린다.
    @State private var tearNotch = 0
    /// 손을 뗀 뒤 끝까지 찢기로 정했는가. 그 뒤에는 끌기가 끊겨도 도로 붙이지 않는다.
    @State private var tearCommitted = false
    /// 지금 누르고 있는가. 시스템이 끌기를 끊으면 `onEnded` 없이 풀린다.
    @GestureState private var touching = false
    @State private var clock = PackTearClock()
    @FocusState private var focused: Bool

    @Environment(PopoverNavigation.self) private var nav
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(wallet: WalletStore, setID: String, setName: String, packCount: Int,
         pending: PacksView.PendingPack?, onCancel: (() -> Void)?,
         onReady: @escaping (PacksView.OpenedPack) -> Void) {
        self.wallet = wallet
        self.setID = setID
        self.setName = setName
        self.packCount = packCount
        self.pending = pending
        self.onCancel = onCancel
        self.onReady = onReady
        _packImage = State(initialValue: CardImageLoader.readyPackImage(setID: setID))
    }

    /// 저 혼자 움직이는 흔들림과 광택. **팝오버가 보일 때만** 돈다 — 닫혀도 화면 트리가 남는다.
    private var ambientLive: Bool {
        nav.isShown && !reduceMotion && phase != .done
    }

    var body: some View {
        let l = wallet.l
        return VStack(spacing: 8) {
            HStack {
                Text(setName).font(Typography.body).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if packCount > 1 {
                    Text("×\(packCount)")
                        .font(Typography.bodySemibold).foregroundStyle(.secondary).monospacedDigit()
                }
            }

            Spacer(minLength: 0)

            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !ambientLive)) { context in
                PackTearStage(setID: setID, packCount: packCount, packImage: packImage,
                              card: emergingCard, pose: pose,
                              ambient: reduceMotion ? .still : clock.ambient(at: context.date),
                              reduceMotion: reduceMotion)
            }
            .frame(width: PackTearMetrics.stageWidth, height: PackTearMetrics.stageHeight)
            .packTearViewport()
            .contentShape(Rectangle())
            .gesture(tearGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(l.packTearAction)
            .accessibilityHint(l.packTearHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { activate() }
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(keys: [.return, .space]) { _ in
                activate()
                return .handled
            }

            info(l)

            Spacer(minLength: 0)

            // 자리는 늘 같은 크기로 둔다. 버튼이 사라질 때 카드 자리가 흔들리면 안 된다.
            Button(l.cancel) { onCancel?() }
                .buttonStyle(.bordered)
                .font(Typography.button)
                .opacity(canCancel ? 1 : 0)
                .disabled(!canCancel)
                .accessibilityHidden(!canCancel)
                .animation(.easeOut(duration: 0.2), value: canCancel)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
        .task(id: setID) {
            guard packImage == nil else { return }
            packImage = await CardImageLoader.packImage(setID: setID)
        }
        .task(id: pending?.id) { await prepare() }
        .onChange(of: loaded?.id) {
            if phase == .torn { extract() }
        }
        // 끌기가 `onEnded` 없이 끊기면(다른 창이 가로채는 등) 찢다 만 띠를 도로 붙인다.
        .onChange(of: touching) {
            if !touching, phase == .tearing, !tearCommitted { springBack() }
        }
        .onDisappear {
            choreography?.cancel()
            choreography = nil
        }
    }

    private var canCancel: Bool { onCancel != nil && phase == .sealed }

    /// 두 줄 안내. 높이는 공개 화면의 이름 줄과 등급 줄과 같다.
    private func info(_ l: L) -> some View {
        let waiting = phase == .torn && loaded == nil
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                if waiting {
                    ProgressView().controlSize(.small)
                }
                Text(waiting ? (packCount == 1 ? l.packPreparing : l.packPreparingCount(packCount))
                             : l.packTearTitle)
                    .font(Typography.title)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
            }
            Text(waiting ? " " : l.packTearHint)
                .font(Typography.label).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
                .contentTransition(.opacity)
        }
        .opacity(phase == .extracting || phase == .done ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: waiting)
        .animation(.easeOut(duration: 0.16), value: phase == .extracting)
    }

    /// 꺼내는 중인 첫 장. 뜯기 전에는 그리지도 않는다 — 팩 그림에 빈틈이 있으면 비친다.
    private var emergingCard: PackTearStage.Card? {
        guard pose.cardShown, let opened = loaded, let first = opened.cards.first else { return nil }
        return PackTearStage.Card(id: first.id,
                                  image: opened.hires[first.id]
                                      ?? CardImageLoader.preparedImage(cardID: first.id, hires: true))
    }

    // MARK: 준비

    /// 첫 장들과 요약 썸네일을 미리 받는다. 한 장씩 넘길 때 받기 시작하면 빈 자리만 지나간다.
    /// 10,000장을 열어도 모든 원본을 기다리지는 않는다.
    private func prepare() async {
        guard let pending else { return }
        let ids = pending.presentation.imageIDs(at: 0)
        let summaryIDs = pending.presentation.summaryCards.prefix(PackPresentation.imageWindow).map(\.id)
        async let hires = CardImageLoader.prefetch(cardIDs: ids, hires: true)
        async let thumbs = CardImageLoader.prefetch(cardIDs: summaryIDs, hires: false)
        let (big, small) = await (hires, thumbs)
        guard !Task.isCancelled else { return }
        loaded = PacksView.OpenedPack(id: pending.id, setName: pending.setName,
                                      packCount: pending.packCount, presentation: pending.presentation,
                                      hires: big, thumbs: small,
                                      completions: pending.completions,
                                      isPreview: pending.isPreview)
    }

    // MARK: 뜯기

    /// 누르기와 밀기를 거리 0 의 끌기 하나로 받는다. 거의 움직이지 않고 떼면 누른 것이다.
    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard phase == .sealed || phase == .tearing else { return }
                if phase == .sealed {
                    phase = .tearing
                    tearNotch = 0
                    tearCommitted = false
                    clock.settle()
                    withAnimation(.easeOut(duration: 0.15)) { pose.hintVisible = 0 }
                }
                let dx = value.translation.width
                // 찢기 시작한 쪽은 처음 민 방향이다. 아직 안 찢었으면 방향을 바꿀 수 있다.
                if pose.tear == 0, abs(dx) > 2 { pose.fromLeading = dx > 0 }
                let tear = PackTearMetrics.tearAmount(dx, fromLeading: pose.fromLeading)
                pose.tear = tear
                let notch = Int(tear / PackTearMetrics.hapticNotch)
                if notch > tearNotch {
                    tearNotch = notch
                    if tear < 1 { PackTearHaptics.rip() }
                }
            }
            .onEnded { value in
                switch phase {
                case .extracting:
                    skipExtraction()
                case .tearing:
                    let moved = (value.translation.width * value.translation.width
                        + value.translation.height * value.translation.height).squareRoot()
                    if moved < PackTearMetrics.tapSlop {
                        autoTear()
                    } else if pose.tear >= PackTearMetrics.commitTear
                                || PackTearMetrics.tearAmount(value.predictedEndTranslation.width,
                                                              fromLeading: pose.fromLeading) >= 1 {
                        finishTear()
                    } else {
                        springBack()
                    }
                default:
                    break
                }
            }
    }

    /// 덜 찢었으면 도로 붙는다. 밀던 힘이 남아 있으니 스프링으로 돌린다.
    private func springBack() {
        phase = .sealed
        clock.stir()
        withAnimation(.spring(PackTearMotion.springBack)) {
            pose.tear = 0
            pose.hintVisible = 1
        }
    }

    /// 누르기, 키보드, 손쉬운 사용이 모두 여기로 온다.
    private func activate() {
        switch phase {
        case .sealed: autoTear()
        case .extracting: skipExtraction()
        default: break
        }
    }

    /// 누르기만 하면 저절로 찢어진다. 찢김은 갈수록 빨라진다.
    private func autoTear() {
        guard phase == .sealed || phase == .tearing else { return }
        phase = .tearing
        tearCommitted = true
        clock.settle()
        pose.fromLeading = true
        if reduceMotion {
            pose.tear = 1
            pose.hintVisible = 0
            stripAway()
            return
        }
        withAnimation(.timingCurve(PackTearMotion.autoTear, duration: PackTearMotion.autoTearDuration)) {
            pose.tear = 1
            pose.hintVisible = 0
        } completion: {
            stripAway()
        }
    }

    /// 손을 뗐을 때 남은 만큼을 마저 찢는다. 남은 길이가 짧을수록 빨리 끝난다.
    private func finishTear() {
        tearCommitted = true
        let remaining = 1 - pose.tear
        withAnimation(.easeOut(duration: 0.06 + 0.14 * remaining)) {
            pose.tear = 1
        } completion: {
            stripAway()
        }
    }

    /// 띠가 떨어져 날아가는 순간. 몸통은 살짝 눌렸다 돌아오고 안에서 빛이 샌다.
    private func stripAway() {
        guard phase == .tearing else { return }
        phase = .opening
        PackTearHaptics.open()
        choreography?.cancel()
        choreography = Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) {
                    pose.stripGone = 1
                    pose.glow = PackTearMotion.restingGlow
                }
            } else {
                withAnimation(.timingCurve(PackTearMotion.stripAway, duration: PackTearMotion.stripAwayDuration)) {
                    pose.stripGone = 1
                }
                withAnimation(.easeOut(duration: PackTearMotion.flashDuration)) {
                    pose.recoil = 1
                    pose.glow = 1
                }
                try? await Task.sleep(for: .seconds(PackTearMotion.flashDuration))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(PackTearMotion.recoilOut)) { pose.recoil = 0 }
                withAnimation(.easeOut(duration: 0.5)) { pose.glow = PackTearMotion.restingGlow }
                // 띠가 거의 빠진 뒤에 카드가 올라온다. 겹치면 시선이 둘로 갈라진다.
                try? await Task.sleep(for: .seconds(PackTearMotion.extractAfterStrip - PackTearMotion.flashDuration))
                guard !Task.isCancelled else { return }
            }
            phase = .torn
            if loaded != nil {
                extract()
            } else {
                // 아직 카드를 받는 중이면 열린 팩이 다시 숨을 쉬며 기다린다.
                clock.stir()
            }
        }
    }

    // MARK: 꺼내기

    private func extract() {
        guard phase == .torn, let opened = loaded else { return }
        if reduceMotion || opened.cards.isEmpty {
            hand(over: opened)
            return
        }
        phase = .extracting
        clock.settle()
        pose.cardShown = true
        choreography?.cancel()
        choreography = Task { @MainActor in
            withAnimation(.timingCurve(PackTearMotion.rise, duration: PackTearMotion.riseDuration)) {
                pose.cardRise = 1
            }
            try? await Task.sleep(for: .seconds(PackTearMotion.exitAfterRise))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(PackTearMotion.bodyExit, duration: PackTearMotion.bodyExitDuration)) {
                pose.bodyGone = 1
                pose.glow = 0
            }
            withAnimation(.spring(PackTearMotion.settle)) { pose.cardSettle = 1 }
            try? await Task.sleep(for: .seconds(PackTearMotion.handOffAfterSettle))
            guard !Task.isCancelled else { return }
            hand(over: opened)
        }
    }

    /// 꺼내는 도중 누르면 기다리지 않고 첫 장으로 간다. 자주 여는 사람의 시간을 잡아 두지 않는다.
    private func skipExtraction() {
        guard phase == .extracting, let opened = loaded else { return }
        choreography?.cancel()
        hand(over: opened)
    }

    private func hand(over opened: PacksView.OpenedPack) {
        guard phase != .done else { return }
        phase = .done
        choreography = nil
        onReady(opened)
    }
}

// MARK: - 모습

/// 한 순간의 모습. 실제 화면과 진단 렌더러가 같은 값을 같은 무대에 그린다.
struct PackTearPose: Equatable {
    /// 찢어진 정도(0~1). 1 이면 끝까지 찢겼다.
    var tear = 0.0
    /// 찢기 시작한 쪽. 반대쪽 끝이 경첩이 된다.
    var fromLeading = true
    /// 띠가 떨어져 나간 정도(0~1).
    var stripGone = 0.0
    /// 찢기는 순간 몸통이 눌리는 정도(0~1).
    var recoil = 0.0
    /// 안에서 새는 빛(0~1). 찢는 동안의 빛은 `tear` 에서 따로 나온다.
    var glow = 0.0
    /// 첫 장을 그리기 시작했는가.
    var cardShown = false
    /// 카드가 팩에서 올라온 정도(0~1). 1 이면 반쯤 나와 있다.
    var cardRise = 0.0
    /// 카드가 밑장 자리로 옮겨 간 정도(0~1).
    var cardSettle = 0.0
    /// 팩 몸통이 아래로 빠진 정도(0~1).
    var bodyGone = 0.0
    /// 뜯을 자리를 알려 주는 빛줄기와 포장지 광택의 세기(0~1).
    var hintVisible = 1.0
}

/// 시간이 정하는 움직임. 손을 대면 0.25초 안에 잦아들고, 놓으면 0.6초에 걸쳐 되살아난다.
struct PackTearAmbient: Equatable {
    var yaw = 0.0
    var roll = 0.0
    var lift = 0.0
    /// 광택 띠의 가로 위치(팩 폭 기준, 0.5 가 가운데).
    var sheenCenter = 0.5
    var sheenStrength = 0.0
    /// 뜯을 자리 빛줄기의 위치(-0.2~1.2). 범위 밖이면 쉬는 중이다.
    var streak = -1.0
    /// 기다리는 동안 빛이 고르게 숨쉬는 배율.
    var pulse = 1.0

    static let still = PackTearAmbient()
}

/// 흔들림의 시계. 멈췄다 다시 움직일 때 튀지 않도록 세기를 이어 붙인다.
struct PackTearClock {
    private let origin = Date()
    private var calmSince: Date?
    private var stirSince = Date.distantPast
    static let calmDuration = 0.25
    static let stirDuration = 0.6

    /// 손을 댔다. 지금 세기에서부터 잦아든다.
    mutating func settle(now: Date = Date()) {
        guard calmSince == nil else { return }
        let current = linearAmplitude(now)
        calmSince = now.addingTimeInterval(-(1 - current) * Self.calmDuration)
    }

    /// 손을 뗐다. 지금 세기에서부터 되살아난다.
    mutating func stir(now: Date = Date()) {
        let current = linearAmplitude(now)
        calmSince = nil
        stirSince = now.addingTimeInterval(-current * Self.stirDuration)
    }

    private func linearAmplitude(_ now: Date) -> Double {
        if let calmSince {
            return max(0, 1 - now.timeIntervalSince(calmSince) / Self.calmDuration)
        }
        return min(1, max(0, now.timeIntervalSince(stirSince) / Self.stirDuration))
    }

    func ambient(at date: Date) -> PackTearAmbient {
        let linear = linearAmplitude(date)
        let amplitude = linear * linear * (3 - 2 * linear)
        return Self.ambient(time: date.timeIntervalSince(origin), amplitude: amplitude)
    }

    /// 진단 렌더러도 같은 식을 쓴다.
    static func ambient(time t: Double, amplitude: Double) -> PackTearAmbient {
        let tau = 2 * Double.pi
        let yaw = 4.5 * sin(tau * t / 3.6) * amplitude
        // 위로만 뜬다. 쉬는 자리보다 아래로 내려가면 바닥에 박힌 것처럼 보인다.
        let lift = 3.2 * (0.5 - 0.5 * cos(tau * t / 2.8)) * amplitude
        // 빛줄기는 2.4초마다 한 번, 0.9초 동안 지나간다. 처음 0.6초는 쉰다.
        let cycle = (t - 0.6).truncatingRemainder(dividingBy: 2.4)
        let travel = t < 0.6 ? -1 : cycle / 0.9
        let streak = travel >= 0 && travel <= 1
            ? -0.2 + 1.4 * (travel * travel * (3 - 2 * travel)) : -1
        return PackTearAmbient(
            yaw: yaw,
            roll: 0.9 * sin(tau * t / 4.4 + 1.1) * amplitude,
            lift: lift,
            sheenCenter: 0.5 - yaw / 4.5 * 0.8,
            sheenStrength: 0.12 + 0.22 * amplitude,
            streak: streak,
            pulse: 1 + 0.1 * sin(tau * t / 1.5))
    }
}

// MARK: - 치수와 박자

enum PackTearMetrics {
    /// 카드 자리. 공개 화면의 카드와 같은 크기다.
    static let stageWidth = RevealPeek.cardWidth
    static let stageHeight = (RevealPeek.cardWidth / 0.717).rounded()
    /// 팩은 카드 자리 높이를 꽉 채운다. 팩 그림은 폭 대 높이가 0.55 다.
    static let packWidth = (stageHeight * 0.55).rounded(.down)
    static let packHeight = (packWidth / 0.55).rounded()
    /// 찢는 선의 높이(팩 높이 비율). 실물처럼 봉합선 바로 아래를 뜯는다 — 더 내리면
    /// 대부분의 팩에서 로고가 반으로 갈린다.
    static let tearLine = 0.085

    /// 이만큼 밀면 끝까지 찢긴다(팩 폭 비율). 폭을 다 밀지 않아도 되게 조금 짧다.
    static let tearReach = 0.82
    /// 이보다 덜 움직이고 떼면 누른 것이다.
    static let tapSlop: CGFloat = 4
    /// 손을 뗐을 때 이만큼 찢겼으면 마저 찢는다.
    static let commitTear = 0.5
    /// 찢는 동안 이 간격마다 한 번 짧게 떨린다.
    static let hapticNotch = 0.25

    static func tearAmount(_ dx: CGFloat, fromLeading: Bool) -> Double {
        let toward = Double(fromLeading ? dx : -dx)
        return min(1, max(0, toward / (Double(packWidth) * tearReach)))
    }

    // 꺼낸 카드: 팩 안(작게, 아래) -> 반쯤 나옴 -> 밑장 자리.
    static let insideScale = 0.62
    static let risenScale = 0.66
    static let insideOffset = 56.0
    static let risenOffset = -88.0

    /// 반쯤 나온 카드를 밑장 자리로 옮기는 배율. 끝 모습이 정확히 `RevealPeek` 의 밑장이다.
    static var settleScale: Double { Double(RevealPeek.deckScale) / risenScale }
    static var settleOffset: Double { Double(RevealPeek.deckOffset) - risenOffset }
}

/// 실제 화면과 진단 렌더러가 함께 쓰는 박자. 한쪽만 고치면 미리보기가 거짓말을 한다.
enum PackTearMotion {
    static let autoTear = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.45, y: 0),
                                           endControlPoint: UnitPoint(x: 0.85, y: 0.55))
    static let autoTearDuration = 0.30
    static let stripAway = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.4, y: 0),
                                            endControlPoint: UnitPoint(x: 1, y: 1))
    static let stripAwayDuration = 0.36
    static let flashDuration = 0.09
    static let recoilOut = Spring(response: 0.36, dampingRatio: 0.6)
    static let restingGlow = 0.62
    /// 띠가 날아가기 시작한 뒤 카드가 올라오기까지.
    static let extractAfterStrip = 0.18
    static let rise = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.2, y: 0),
                                       endControlPoint: UnitPoint(x: 0, y: 1))
    static let riseDuration = 0.5
    /// 카드가 올라오기 시작한 뒤 팩이 빠지기까지.
    static let exitAfterRise = 0.26
    static let bodyExit = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.4, y: 0),
                                           endControlPoint: UnitPoint(x: 1, y: 1))
    static let bodyExitDuration = 0.34
    static let settle = Spring(response: 0.46, dampingRatio: 0.86)
    /// 카드가 밑장 자리로 가기 시작한 뒤 첫 장 화면으로 넘기기까지.
    static let handOffAfterSettle = 0.42
    static let springBack = Spring(response: 0.34, dampingRatio: 0.82)
}

@MainActor
enum PackTearHaptics {
    /// 찢는 동안의 짧은 떨림.
    static func rip() { perform(.generic) }
    /// 띠가 떨어지는 순간.
    static func open() { perform(.levelChange) }

    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

// MARK: - 무대

/// 팩과 꺼내는 카드를 그리는 자리. 상태 없이 모습만 받아 그린다.
@MainActor
struct PackTearStage: View {
    struct Card: Equatable {
        let id: String
        let image: NSImage?
    }

    let setID: String
    let packCount: Int
    let packImage: NSImage?
    let card: Card?
    let pose: PackTearPose
    let ambient: PackTearAmbient
    let reduceMotion: Bool

    private var edge: [CGPoint] { PackTearEdge.points(for: setID) }
    private var direction: Double { pose.fromLeading ? 1 : -1 }
    /// 찢는 동안 새는 빛과 다 찢은 뒤의 빛을 합친다. 띠가 빠지면 앞의 것은 사라진다.
    private var glowAmount: Double {
        min(1, pose.glow + 0.7 * pose.tear * (1 - pose.stripGone)) * ambient.pulse
    }

    var body: some View {
        ZStack {
            Group {
                backPacks
                innerGlow
            }
            .offset(y: bodyExitOffset)
            .opacity(bodyOpacity)

            if let card {
                CardImageView(cardID: card.id, hires: true, width: PackTearMetrics.stageWidth,
                              preloaded: card.image)
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                    .scaleEffect(PackTearMetrics.insideScale
                        + (PackTearMetrics.risenScale - PackTearMetrics.insideScale) * pose.cardRise)
                    .scaleEffect(1 + (PackTearMetrics.settleScale - 1) * pose.cardSettle)
                    .offset(y: PackTearMetrics.insideOffset
                        + (PackTearMetrics.risenOffset - PackTearMetrics.insideOffset) * pose.cardRise)
                    .offset(y: PackTearMetrics.settleOffset * pose.cardSettle)
            }

            face(.body)
                .shadow(color: .black.opacity(0.26), radius: 9, y: 6)
                .scaleEffect(1 - 0.012 * pose.recoil, anchor: .bottom)
                .offset(y: (reduceMotion ? 0 : 3 * pose.recoil) + bodyExitOffset)
                .opacity(bodyOpacity)

            strip
            tearGuide
        }
        .frame(width: PackTearMetrics.stageWidth, height: PackTearMetrics.stageHeight)
        // 흔들림은 팩 전체에 한 번만 건다. 조각마다 걸면 찢긴 선이 어긋난다.
        .rotation3DEffect(.degrees(ambient.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotationEffect(.degrees(ambient.roll))
        .offset(y: -ambient.lift)
    }

    /// 팩은 카드 앞을 쓸어내리며 빠진다. 카드가 위에서부터 드러나는 것이 실물에서 포장을
    /// 벗기는 모습이다. 카드 자리 아래에서 `packTearViewport` 가 부드럽게 지운다.
    private var bodyExitOffset: Double { reduceMotion ? 0 : 380 * pose.bodyGone }

    /// 카드와 겹친 동안에는 흐려지지 않는다. 반투명한 팩이 카드 위에 겹치면 두 그림이 섞여 보인다.
    /// 팩 윗변이 카드 밑을 다 지난 뒤(0.8)에야 흐려진다.
    private var bodyOpacity: Double {
        let late = min(1, max(0, (pose.bodyGone - 0.8) / 0.2))
        return 1 - late * late * (3 - 2 * late)
    }

    // MARK: 조각

    private enum Piece { case strip, body }

    /// 팩 그림을 찢긴 선으로 자른 조각. 광택과 찢긴 섬유는 그림이 있는 곳에만 얹는다.
    private func face(_ piece: Piece) -> some View {
        // 광택은 팩보다 크게 그려 기울여 둔다. 덧그림(overlay)으로 얹어야 조각 크기가 팩 그대로다.
        PackImageView(setID: setID, width: PackTearMetrics.packWidth, preloaded: packImage)
            .overlay { sheen.blendMode(.sourceAtop) }
            .overlay { fiber.blendMode(.sourceAtop) }
            .compositingGroup()
            .mask(PackTearPiece(side: piece == .strip ? .strip : .body, edge: edge))
    }

    /// 떨어져 나가는 띠. 찢는 동안은 먼 쪽 끝을 경첩 삼아 들리고, 다 찢으면 날아간다.
    private var strip: some View {
        let hinge = UnitPoint(x: pose.fromLeading ? 1 : 0, y: PackTearMetrics.tearLine)
        let peel = pow(pose.tear, 1.3)
        let gone = reduceMotion ? 0 : pose.stripGone
        return face(.strip)
            .shadow(color: .black.opacity(0.22 * pose.tear), radius: 4, y: 2)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : 24 * peel),
                              axis: (x: 1, y: 0, z: 0), anchor: hinge, perspective: 0.5)
            .rotationEffect(.degrees(-direction * 12 * peel), anchor: hinge)
            .rotationEffect(.degrees(-direction * 38 * gone))
            .scaleEffect(1 - 0.1 * gone)
            .offset(x: direction * 84 * gone, y: -150 * gone)
            .opacity(1 - pose.stripGone)
    }

    /// 봉합선 너머 빛. 몸통 뒤에 두어 찢긴 틈과 열린 입구로만 보인다.
    ///
    /// 띠가 붙어 있는 동안은 띠 자리 안에서만 보인다 — 아직 막힌 팩 위로 빛이 번지면
    /// 틈이 아니라 팩 뒤에 등을 켠 것처럼 보인다. 띠가 빠진 만큼 입구 위로 넘친다.
    private var innerGlow: some View {
        let tearY = (PackTearMetrics.tearLine - 0.5) * PackTearMetrics.packHeight
        let from = pose.fromLeading ? -0.5 : 0.5
        // 찢는 동안은 벌어진 쪽으로 치우치고, 다 찢으면 가운데로 모인다.
        let centerX = (from + (0 - from) * min(1, pose.tear + pose.stripGone)) * PackTearMetrics.packWidth * 0.6
        return ZStack {
            Ellipse()
                .fill(EllipticalGradient(colors: [PackTearPalette.glow.opacity(0.9),
                                                  PackTearPalette.glow.opacity(0.32), .clear],
                                         center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                .frame(width: PackTearMetrics.packWidth * 1.15, height: 84)
            Ellipse()
                .fill(EllipticalGradient(colors: [.white, PackTearPalette.glow.opacity(0.5), .clear],
                                         center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                .frame(width: PackTearMetrics.packWidth * 0.78, height: 26)
        }
        .offset(x: centerX, y: tearY)
        .opacity(glowAmount)
        .mask {
            ZStack {
                // 틈의 빛은 찢긴 선에서 가장 밝고 팩 윗변으로 갈수록 사라진다. 고르게 채우면
                // 들린 띠 위로 원래 띠 모양의 밝은 사각형이 남는다.
                PackTearPiece(side: .strip, edge: edge)
                    .fill(LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: PackTearMetrics.tearLine * 0.2),
                        .init(color: .black, location: PackTearMetrics.tearLine),
                    ], startPoint: .top, endPoint: .bottom))
                    .frame(width: PackTearMetrics.packWidth, height: PackTearMetrics.packHeight)
                Rectangle().opacity(pose.stripGone * 0.85)
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// 겹쳐 연 팩. 맨 위 한 장만 뜯는다.
    @ViewBuilder
    private var backPacks: some View {
        let layers = min(2, max(0, packCount - 1))
        ForEach(0..<layers, id: \.self) { layer in
            PackImageView(setID: setID, width: PackTearMetrics.packWidth, preloaded: packImage)
                .brightness(-0.22)
                .saturation(0.85)
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                .rotationEffect(.degrees(layer == 0 ? -4 : 3.5))
                .offset(x: layer == 0 ? -9 : 9, y: layer == 0 ? 4 : 8)
                .zIndex(-Double(layer))
        }
    }

    /// 포장지 광택. 팩이 흔들리는 쪽으로 오간다.
    private var sheen: some View {
        let width = Double(PackTearMetrics.packWidth)
        let center = (ambient.sheenCenter - 0.5) * width
        return LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.0), location: 0.28),
            .init(color: .white.opacity(0.85), location: 0.47),
            .init(color: Color(red: 0.86, green: 0.95, blue: 1).opacity(0.6), location: 0.53),
            .init(color: .white.opacity(0.0), location: 0.72),
            .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing)
        .frame(width: width * 0.9, height: Double(PackTearMetrics.packHeight) * 1.5)
        .rotationEffect(.degrees(18))
        .offset(x: center)
        .opacity(ambient.sheenStrength * pose.hintVisible)
    }

    /// 찢긴 단면의 흰 종이 섬유. 찢긴 만큼만 보인다.
    private var fiber: some View {
        PackTearLine(edge: edge)
            .stroke(PackTearPalette.fiber, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            .mask(tornSpan)
            .opacity(min(1, pose.tear * 3))
    }

    /// 찢기 시작한 쪽부터 찢긴 곳까지. 끝은 부드럽게 흐린다.
    private var tornSpan: some View {
        let reach = min(1, pose.tear + pose.stripGone)
        let edgeStop = max(0.001, min(0.999, reach))
        return LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: max(0, edgeStop - 0.06)),
            .init(color: .clear, location: edgeStop),
        ], startPoint: pose.fromLeading ? .leading : .trailing,
           endPoint: pose.fromLeading ? .trailing : .leading)
    }

    /// 뜯을 자리. 옅은 점선 위로 빛줄기가 한 번씩 지나간다.
    private var tearGuide: some View {
        let streak = ambient.streak
        return ZStack {
            // 흰 포장지에서도 보이게 옅은 그늘을 깐다.
            PackTearLine(edge: edge)
                .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2.5, 3.5]))
                .shadow(color: .black.opacity(0.45), radius: 0.8, y: 0.5)
            if streak >= -0.2 && streak <= 1.2 {
                PackTearLine(edge: edge)
                    .stroke(LinearGradient(stops: [
                        .init(color: .clear, location: max(0, streak - 0.14)),
                        .init(color: .white, location: min(1, max(0, streak))),
                        .init(color: .clear, location: min(1, streak + 0.14)),
                    ], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .shadow(color: PackTearPalette.glow.opacity(0.9), radius: 3)
            }
        }
        .frame(width: PackTearMetrics.packWidth, height: PackTearMetrics.packHeight)
        .blendMode(.plusLighter)
        .opacity(pose.hintVisible * (1 - pose.tear))
        .allowsHitTesting(false)
    }
}

extension View {
    /// 무대 밖으로 나가는 것의 경계. 위와 옆은 열어 두어 날아가는 띠가 잘리지 않게 하고,
    /// 아래는 카드 자리 밑에서 부드럽게 닫는다 — 빠지는 팩이 종료 버튼 줄 뒤로 비치지 않는다.
    func packTearViewport() -> some View {
        mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 50)
            }
            .padding(.top, -420)
            .padding(.horizontal, -220)
            .padding(.bottom, -70)
        }
    }
}

/// 팩 화면에서만 쓰는 빛깔. 어느 팩이든 같다 — 색이 결과를 미리 말하면 안 된다.
enum PackTearPalette {
    static let glow = Color(red: 1.0, green: 0.95, blue: 0.84)
    static let fiber = Color(white: 0.97)
}

// MARK: - 찢긴 선

/// 찢긴 선. 같은 세트의 팩은 언제나 같은 모양으로 찢어진다.
enum PackTearEdge {
    /// 세트 ID 로 씨앗을 정한다. `hashValue` 는 실행마다 달라져서 쓰지 않는다.
    static func seed(_ setID: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in setID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    @MainActor private static var cache: [String: [CGPoint]] = [:]

    /// 흔들리는 동안 매 프레임 다시 그린다. 같은 선을 매번 새로 만들지 않는다.
    @MainActor
    static func points(for setID: String) -> [CGPoint] {
        if let cached = cache[setID] { return cached }
        let made = points(seed: seed(setID))
        cache[setID] = made
        return made
    }

    /// 단위 좌표(팩 폭과 높이를 1로 본다)의 꺾은선. 큰 굴곡 위에 잔 톱니를 얹는다.
    static func points(seed: UInt64) -> [CGPoint] {
        var random = TearRandom(seed: seed)
        let phase = random.next() * 2 * Double.pi
        var result: [CGPoint] = []
        var x = 0.0
        while x < 1 {
            let wobble = sin(x * 9.3 + phase) * 0.004
            let tooth = (random.next() - 0.5) * (random.next() < 0.18 ? 0.02 : 0.011)
            result.append(CGPoint(x: x, y: PackTearMetrics.tearLine + wobble + tooth))
            x += 0.022 + random.next() * 0.018
        }
        result.append(CGPoint(x: 1, y: PackTearMetrics.tearLine + sin(9.3 + phase) * 0.004))
        return result
    }
}

private struct TearRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}

/// 찢긴 선의 위(띠) 또는 아래(몸통).
struct PackTearPiece: Shape {
    enum Side { case strip, body }
    let side: Side
    let edge: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let points = edge.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        guard let first = points.first, let last = points.last else { return Path(rect) }
        var path = Path()
        switch side {
        case .strip:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: last.y))
            for point in points.reversed() { path.addLine(to: point) }
            path.addLine(to: CGPoint(x: rect.minX, y: first.y))
        case .body:
            path.move(to: CGPoint(x: rect.minX, y: first.y))
            for point in points { path.addLine(to: point) }
            path.addLine(to: CGPoint(x: rect.maxX, y: last.y))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// 찢긴 선 자체. 섬유와 안내선을 긋는다.
struct PackTearLine: Shape {
    let edge: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, point) in edge.enumerated() {
            let location = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
        }
        return path
    }
}

// MARK: - 진단

/// 실제 무대와 실제 박자로 개봉 장면을 프레임마다 PNG 로 뽑는다. 손으로 찍은 화면 녹화는
/// 프레임이 들쭉날쭉해 전후를 견줄 수 없다. 손가락이 0.55초 동안 62%를 밀고 놓는 대본이다.
@MainActor
enum PackTearDiagnostics {
    struct Request {
        let setID: String
        let cardID: String
        let outputDirectory: URL
        let dark: Bool
        let packCount: Int
        let fps: Double
    }

    enum Failure: LocalizedError {
        case malformedArguments
        case unknownCard(String)
        case renderingFailed(Int)

        var errorDescription: String? {
            switch self {
            case .malformedArguments:
                "Usage: --render-pack-tear <set-id> <first-card-id> <output-directory> [--dark] [--packs N] [--fps N]"
            case .unknownCard(let cardID): "Not in the card index: \(cardID)"
            case .renderingFailed(let frame): "PNG rendering failed: frame \(frame)"
            }
        }
    }

    static func request(from arguments: [String]) -> Request? {
        guard let flag = arguments.firstIndex(of: "--render-pack-tear") else { return nil }
        guard arguments.indices.contains(flag + 3) else {
            return Request(setID: "", cardID: "", outputDirectory: URL(fileURLWithPath: ""),
                           dark: false, packCount: 1, fps: 60)
        }
        func number(_ name: String, _ fallback: Double) -> Double {
            guard let i = arguments.firstIndex(of: name), arguments.indices.contains(i + 1) else { return fallback }
            return Double(arguments[i + 1]) ?? fallback
        }
        return Request(setID: arguments[flag + 1], cardID: arguments[flag + 2],
                       outputDirectory: URL(fileURLWithPath: arguments[flag + 3], isDirectory: true),
                       dark: arguments.contains("--dark"),
                       packCount: max(1, Int(number("--packs", 1))),
                       fps: max(1, number("--fps", 60)))
    }

    // 대본의 박자. 실제 화면은 `PackTearMotion` 으로 움직이고, 여기는 그 값을 시간으로 푼다.
    private static let dragStart = 1.4
    private static let dragEnd = 1.95
    private static let releasedTear = 0.62
    private static var finishDuration: Double { 0.06 + 0.14 * (1 - releasedTear) }
    private static var stripStart: Double { dragEnd + finishDuration }
    private static var extractStart: Double { stripStart + PackTearMotion.extractAfterStrip }
    private static var exitStart: Double { extractStart + PackTearMotion.exitAfterRise }
    private static var handOff: Double { exitStart + PackTearMotion.handOffAfterSettle }
    /// 첫 장 화면의 등장(`SpotlightCard`)과 같은 스프링.
    private static let landing = Spring(response: 0.34, dampingRatio: 0.7)
    private static var end: Double { handOff + 0.7 }

    private static func progress(_ t: Double, from start: Double, duration: Double, curve: UnitCurve) -> Double {
        guard t > start else { return 0 }
        return curve.value(at: min(1, (t - start) / duration))
    }

    private static func spring(_ t: Double, from start: Double, _ spring: Spring) -> Double {
        guard t > start else { return 0 }
        return spring.value(target: 1.0, time: t - start)
    }

    /// 시간 t 의 모습과 흔들림.
    static func frame(at t: Double) -> (pose: PackTearPose, ambient: PackTearAmbient) {
        var pose = PackTearPose()
        let calm = t < dragStart ? 1 : max(0, 1 - (t - dragStart) / PackTearClock.calmDuration)
        let amplitude = calm * calm * (3 - 2 * calm)
        pose.hintVisible = 1 - progress(t, from: dragStart, duration: 0.15, curve: .easeOut)
        if t > dragStart {
            let finger = min(1, (t - dragStart) / (dragEnd - dragStart))
            pose.tear = releasedTear * finger * finger * (3 - 2 * finger)
        }
        if t > dragEnd {
            pose.tear = releasedTear + (1 - releasedTear)
                * progress(t, from: dragEnd, duration: finishDuration, curve: .easeOut)
        }
        pose.stripGone = progress(t, from: stripStart, duration: PackTearMotion.stripAwayDuration,
                                  curve: PackTearMotion.stripAway)
        let flashEnd = stripStart + PackTearMotion.flashDuration
        if t > stripStart {
            let flash = progress(t, from: stripStart, duration: PackTearMotion.flashDuration, curve: .easeOut)
            pose.recoil = t < flashEnd ? flash : 1 - spring(t, from: flashEnd, PackTearMotion.recoilOut)
            let settleGlow = progress(t, from: flashEnd, duration: 0.5, curve: .easeOut)
            pose.glow = t < flashEnd ? flash : 1 + (PackTearMotion.restingGlow - 1) * settleGlow
        }
        if t > extractStart {
            pose.cardShown = true
            pose.cardRise = progress(t, from: extractStart, duration: PackTearMotion.riseDuration,
                                     curve: PackTearMotion.rise)
        }
        if t > exitStart {
            let exit = progress(t, from: exitStart, duration: PackTearMotion.bodyExitDuration,
                                curve: PackTearMotion.bodyExit)
            pose.bodyGone = exit
            pose.glow *= 1 - exit
            pose.cardSettle = spring(t, from: exitStart, PackTearMotion.settle)
        }
        return (pose, PackTearClock.ambient(time: t, amplitude: amplitude))
    }

    static func render(_ request: Request) async throws -> [URL] {
        guard !request.setID.isEmpty, !request.outputDirectory.path.isEmpty else {
            throw Failure.malformedArguments
        }
        guard let card = CardIndex.shared?.card(request.cardID) else {
            throw Failure.unknownCard(request.cardID)
        }
        let packImage = await CardImageLoader.packImage(setID: request.setID)
        let cardImage = await CardImageLoader.image(cardID: request.cardID, hires: true)
        let finish = CardFinishResolver.resolve(cardID: card.id, setID: card.setID,
                                                originalRarity: card.rarity, tier: card.tier,
                                                visualKind: card.visualKind).finish
        try FileManager.default.createDirectory(at: request.outputDirectory,
                                                withIntermediateDirectories: true)
        var files: [URL] = []
        let count = Int((end * request.fps).rounded(.up))
        for index in 0...count {
            let t = Double(index) / request.fps
            let content: AnyView
            if t < handOff {
                let (pose, ambient) = frame(at: t)
                content = AnyView(PackTearStage(
                    setID: request.setID, packCount: request.packCount, packImage: packImage,
                    card: pose.cardShown ? PackTearStage.Card(id: card.id, image: cardImage) : nil,
                    pose: pose, ambient: ambient, reduceMotion: false))
            } else {
                // 넘긴 뒤: 첫 장 화면이 밑장 자리에서 제자리로 올라오는 모습.
                let landed = spring(t, from: handOff, landing)
                content = AnyView(HolographicCardView(cardID: card.id, tier: card.tier, finish: finish,
                                                      width: PackTearMetrics.stageWidth, preloaded: cardImage)
                    .environment(\.valueAwareGlow, true)
                    .scaleEffect(RevealPeek.deckScale + (1 - RevealPeek.deckScale) * landed)
                    .offset(y: RevealPeek.deckOffset * (1 - landed)))
            }
            let view = ZStack {
                (request.dark ? Color(white: 0.16) : Color(white: 0.93))
                content
                    .frame(width: PackTearMetrics.stageWidth, height: PackTearMetrics.stageHeight)
                    .packTearViewport()
            }
            .frame(width: PackTearMetrics.stageWidth + 90, height: PackTearMetrics.stageHeight + 150)
            .environment(\.colorScheme, request.dark ? .dark : .light)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw Failure.renderingFailed(index)
            }
            let file = request.outputDirectory.appendingPathComponent(String(format: "frame-%04d.png", index))
            try png.write(to: file, options: .atomic)
            files.append(file)
        }
        return files
    }
}
