import AppKit
import SwiftUI

/// 기획에 필요한 탭만 둔다 — 팩을 사고, 팩을 열고, 카드를 본다.
/// 잔액과 사용량은 탭이 아니라 상단 고정 영역이 맡는다.
enum PopoverTab: CaseIterable { case shop, packs, collection, dex, stats }

/// 팝오버 크기. 설정에서 고르고, 앱을 다시 켤 때 적용된다.
///
/// 큰 화면에서는 카드가 작아 그림을 보려면 매번 상세를 열어야 했다. 글자는 그대로 두고
/// 창과 카드 격자만 키운다.
enum PopoverSize: String, CaseIterable, Sendable {
    case regular, large

    static let defaultsKey = "popoverSize"

    /// 이번 실행의 크기. 치수가 화면 곳곳의 정적 값이라 실행 중에는 바꾸지 않는다.
    /// `PPB_POPOVER_SIZE` 는 레이아웃 감사가 큰 창을 따로 재 볼 때 쓴다.
    static let launch: PopoverSize = {
        let forced = ProcessInfo.processInfo.environment["PPB_POPOVER_SIZE"]
        let stored = UserDefaults.standard.string(forKey: defaultsKey)
        return PopoverSize(rawValue: forced ?? stored ?? "") ?? .regular
    }()
}

/// 팝오버 치수의 단일 소스. 자식이 쓸 수 있는 폭을 알아야 할 때 이 값을 쓴다 — 넘치는 자식이
/// 부모 폭을 부풀리므로 GeometryReader 로 재면 순환한다.
enum PopoverMetrics {
    private static let large = PopoverSize.launch == .large

    /// 글자 크기는 유지하고 창과 카드 격자만 약 10% 줄인 기본 크기. 크게 고르면 15% 넓다.
    static let width: CGFloat = large ? 460 : 400
    static let padding: CGFloat = 14
    /// 이 폭을 넘는 자식은 팝오버 창에 좌우로 잘린다.
    static let contentWidth: CGFloat = width - padding * 2

    /// 탭 하나가 쓰는 세로 길이.
    static let tabHeight: CGFloat = large ? 580 : 480

    /// 개봉 화면의 이름·가격·이동 버튼·밑장 여백을 먼저 확보한다.
    static let revealCardWidth = min(large ? 300 : 260, ((tabHeight - 170) * 0.717).rounded(.down))
    /// 오리파는 상점 갈래 선택과 NEW 배지 자리가 추가로 필요하다.
    static let pulledCardWidth = min(large ? 276 : 240, ((tabHeight - 190) * 0.717).rounded(.down))
}

/// 팝오버 내부 내비게이션 상태.
///
/// 화면 트리는 처음 열 때 한 번 만들고 닫아도 버리지 않으므로, 여기 담긴 것도 화면에 담긴
/// `@State` 도 닫았다 열면 그대로 남는다. **일부러 그렇게 둔다** — 팩을 뜯다 닫았을 때
/// 뜯던 자리로 돌아오는 것이 이 앱에서 기대되는 동작이다.
@MainActor
@Observable
final class PopoverNavigation {
    var showSettings = false
    var showReleaseNotes = false
    var tab: PopoverTab = .shop

    /// 팝오버가 지금 보이는가.
    ///
    /// 화면 트리를 닫아도 버리지 않으므로, 끝없이 도는 애니메이션은 **보일 때만** 돌려야 한다.
    /// 안 그러면 닫힌 채로도 계속 다시 그린다. 앱이 팝오버 델리게이트에서 채운다.
    var isShown = false

    /// 상점에서 바로 열어야 할 팩. 도감의 「이 팩 사러 가기」가 채운다.
    /// 상점이 한 번 읽고 지운다 — 남겨 두면 다음에 상점을 열 때 또 그 팩이 뜬다.
    var shopSet: String?

    /// 도감 탭에서 바로 열어야 할 도감. 카드 상세의 도감 배지가 채운다.
    var dexID: String?

    /// 도감 탭을 이 검색어로 연다. 카드 상세에서 보이지 않는 나머지 도감(「+N」)을 볼 때 쓴다.
    var dexSearch: String?

    /// 상점에서 팩 탭으로 날아가는 중인 팩 그림.
    var packFlights: [PackFlight] = []
    /// 팩 탭이 열리면 그 줄로 옮겨 가 한 번 빛낼 세트. 상점의 「팩 탭에서 열기」 가 채운다.
    var packHighlight: String?
    /// 방금 받은 도감 보상 알림. 잠깐 띄웠다가 걷는다.
    var rewardNotice: RewardNotice?
    /// 지금 터지고 있는 반짝임.
    var sparks: [SparkEvent] = []

    /// 화면에 떠 있는 뒤로 버튼들. 버튼이 나타날 때 스스로 올리고 사라질 때 내린다.
    ///
    /// 가장 나중에 올라온 것이 가장 깊은 화면이다. 깊이를 따로 적어 두지 않아도 한 단계씩
    /// 들어갈 때마다 새 화면의 버튼이 위에 쌓인다. 그리는 데 쓰는 값이 아니라 지켜보지 않는다.
    @ObservationIgnored private var backHandlers: [PopoverBackHandler] = []

    func registerBack(_ handler: PopoverBackHandler) {
        backHandlers.removeAll { $0 === handler }
        backHandlers.append(handler)
    }

    func unregisterBack(_ handler: PopoverBackHandler) {
        backHandlers.removeAll { $0 === handler }
    }

    /// Esc. 한 단계 뒤로 간다. 돌아갈 곳이 없으면(탭의 첫 화면) `false` 라서 팝오버가 닫힌다.
    ///
    /// 예전에는 어느 화면에서든 Esc 가 팝오버를 통째로 닫았다. 팩 상세나 카드 상세에서
    /// 목록으로 돌아가려고 누르면 창이 사라져, 다시 열고 뒤로 버튼을 눌러야 했다.
    func goBack() -> Bool {
        guard let handler = backHandlers.last else { return false }
        handler.action()
        return true
    }
}

/// 뒤로 버튼 하나가 Esc 에 맡기는 동작. 버튼이 다시 그려질 때마다 최신 동작으로 바꿔 끼운다.
@MainActor
final class PopoverBackHandler {
    var action: () -> Void = {}
}

@MainActor
struct PopoverView: View {
    @Environment(UsageStore.self) private var store
    @Environment(WalletStore.self) private var wallet
    @Environment(UpdateChecker.self) private var updater
    @Environment(PopoverNavigation.self) private var nav

    private static let index = CardIndex.shared

    private var l: L { wallet.l }

    /// 물음표에 마우스가 올라와 있는가. 환산 안내가 이 값만 보고 뜬다 — 누르고 닫는
    /// 동작을 만들지 않는다. 한 줄짜리 안내를 보려고 두 번 누르게 할 이유가 없다.
    @State private var hoveringRate = false
    @State private var priceRevision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if wallet.isOnline { onlineEntry }
            if let remote = wallet.remote, !remote.ready || remote.error != nil {
                Button { nav.showSettings = true } label: {
                    Label(remote.error ?? l.connectingToServer, systemImage: "network")
                        .font(Typography.caption).lineLimit(2)
                }.buttonStyle(.plain).foregroundStyle(.orange)
            }
            if let remote = wallet.remote, let recovered = remote.recoveredResult {
                HStack {
                    Text(l.recoveredRequest(recovered.packs?.packs.count))
                        .font(Typography.caption)
                    Button(l.done) { remote.dismissRecoveredResult() }
                }
            }
            if let error = wallet.persistenceError {
                VStack(alignment: .leading, spacing: 3) {
                    Label(l.saveFailed, systemImage: "exclamationmark.triangle")
                    Text(error).font(Typography.label).textSelection(.enabled)
                }.foregroundStyle(.red)
            } else if wallet.recoveredSave {
                Text(l.saveRecovered).font(Typography.label).foregroundStyle(.orange)
            }
            // 패치 노트를 먼저 본다 — 설정에서 열었을 때 닫으면 설정으로 돌아가게 하려는 것이다.
            if nav.showReleaseNotes {
                ReleaseNotesView(wallet: wallet, store: store,
                                 onClose: { nav.showReleaseNotes = false })
            } else if nav.showSettings {
                SettingsView(onClose: { nav.showSettings = false },
                             onOpenReleaseNotes: { nav.showReleaseNotes = true })
            } else {
                walletHeader
                // 선물과 보너스 팩 알림은 위에서 내려오고, 닫으면 걷혀 올라간다. 툭 나타나면
                // 아래 화면이 한 번에 밀려 무엇이 생겼는지보다 덜컹거림이 먼저 보인다.
                Group {
                    giftToast
                    bonusToast
                }
                .animation(.snappy(duration: 0.3), value: wallet.lastGift != nil)
                .animation(.snappy(duration: 0.3), value: wallet.lastGrant != nil)
                releaseNotesToast
                onboardingCard
                tabPicker
                    // 산 팩이 날아가 내려앉을 자리. 탭 줄의 「팩」 칸 가운데다.
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { tabBarFrame = proxy.frame(in: .named(PackFlight.space)) }
                                .onChange(of: proxy.frame(in: .named(PackFlight.space))) {
                                    tabBarFrame = proxy.frame(in: .named(PackFlight.space))
                                }
                        }
                    }
                tabContent
            }

            Divider()
            HStack {
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label(l.quit, systemImage: "power")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .coordinateSpace(.named(PackFlight.space))
        .environment(\.popoverShown, nav.isShown)
        .overlay { CelebrationLayer(wallet: wallet) }
        .overlay {
            PackFlightLayer(flights: nav.packFlights, target: packsTabCenter) { flight in
                nav.packFlights.removeAll { $0.id == flight.id }
            }
        }
        .id(priceRevision)
        .onReceive(NotificationCenter.default.publisher(for: PriceSnapshotStore.changed)) { _ in
            priceRevision += 1
        }
        // 안쪽 폭을 못 박는다. 자식이 이 폭보다 넓으면 창이 통째로 넓어지고, 창은
        // `width` 로 고정돼 있으므로 남는 만큼 왼쪽으로 밀린다 — 탭 하나만 넓어도
        // 상단 머리글이 그 탭에서만 옆으로 덜컹거렸다. 넘치는 자식은 제 자리에서
        // 잘리게 두고, 머리글은 어느 탭에서든 같은 자리에 둔다.
        .frame(width: PopoverMetrics.contentWidth, alignment: .leading)
        .padding(PopoverMetrics.padding)
        .frame(width: PopoverMetrics.width)
    }

    // MARK: 온라인 창 입구

    /// 온라인 창을 여는 줄. 캡션 크기 글자만 있던 예전 버튼은 찾기도 누르기도 어려웠다.
    /// 아이콘과 설명을 붙인 한 줄 전체를 누를 수 있게 하고, ⌘O 로도 연다.
    private var onlineEntry: some View {
        let summary = wallet.remote?.notificationSummary
        let pending = Self.pendingText(summary, l)
        return Button { OnlineWindow.shared.show(wallet: wallet, section: Self.section(for: summary)) } label: {
            HStack(spacing: 9) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(l.online).font(Typography.bodySemibold)
                // 답할 것이 있으면 기능 소개 대신 그 개수를 보여 준다. 예전에는 온라인 창을 열어
                // 봐야만 교환 제안이 왔는지 알 수 있었다.
                Text(pending ?? l.onlineEntryFeatures).font(pending == nil ? Typography.label : Typography.labelSemibold)
                    .foregroundStyle(pending == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("⌘O").font(Typography.caption).foregroundStyle(.tertiary)
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(OnlineEntryButtonStyle())
        .keyboardShortcut("o", modifiers: .command)
        .help(l.openOnlineWindow)
        .accessibilityLabel(pending.map { "\(l.openOnlineWindow), \($0)" } ?? l.openOnlineWindow)
        .accessibilityHint(l.openOnlineWindowHint)
    }

    /// 답해야 할 것부터. 교환 제안은 72시간이 지나면 사라지므로 맨 앞이다.
    static func pendingText(_ summary: RemoteGameSession.NotificationSummary?, _ l: L) -> String? {
        guard let summary, !summary.isEmpty else { return nil }
        var parts: [String] = []
        if summary.incoming_trades > 0 { parts.append(l.pendingTrades(summary.incoming_trades)) }
        if summary.incoming_friends > 0 { parts.append(l.pendingFriends(summary.incoming_friends)) }
        if summary.unread > 0 { parts.append(l.pendingAlerts(summary.unread)) }
        return parts.joined(separator: ", ")
    }

    /// 눌렀을 때 바로 보여 줄 탭.
    static func section(for summary: RemoteGameSession.NotificationSummary?) -> OnlineHubModel.Tab? {
        guard let summary else { return nil }
        if summary.incoming_trades > 0 { return .trades }
        if summary.incoming_friends > 0 { return .social }
        if summary.unread > 0 { return .alerts }
        return nil
    }

    // MARK: 상단 — 재화와 사용량

    private var walletHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 두 숫자를 같은 틀로 세운다. 이름줄과 숫자줄이 각각 한 선에 놓여야 나란히 읽힌다.
            // 모으는 것은 토큰이지만 읽는 것은 원이다 — 카드 시세가 실제 시장에서 온 값이라,
            // 팩 값과 잔액도 같은 단위로 읽어야 비교가 된다.
            HStack(alignment: .top, spacing: 10) {
                headerStat(l.walletBalance,
                           MarketEconomy.money(tokens: wallet.availableTokens,
                                               language: wallet.language),
                           tint: nil, hint: true)
                collectionWorth
                Spacer(minLength: 4)
                // 새 버전이 있으면 설정 옆에 바로 띄운다. 설정 안에 숨겨 두면
                // 들어가 보지 않는 한 업데이트가 있는지도 모른다.
                if let update = updater.available {
                    Button {
                        updater.applyUpdate()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(update.version).monospacedDigit()
                        }
                        .font(Typography.labelSemibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updater.isUpdating)
                    .help(l.updateAvailableHelp(update.version))
                }
                Button {
                    nav.showSettings = true
                } label: {
                    Image(systemName: "gearshape").font(.system(size: 17))
                }
                .buttonStyle(.borderless)
                .help(l.settings)
            }

            if wallet.awaitingFirstUsage {
                Text(l.awaitingUsage)
                    .font(Typography.label).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 5) {
                    Text("\(l.todayTokens) \(TokenFormatter.readable(store.todayTotalTokens, language: wallet.language))")
                        .monospacedDigit()
                    if let top = topWindow {
                        Text("·")
                        Text("\(top.name) \(Int(top.utilization.rounded()))%").monospacedDigit()
                    }
                }
                .font(Typography.label).foregroundStyle(.secondary)
                .lineLimit(1)

                if let top = topWindow {
                    ProgressView(value: min(top.utilization, 100), total: 100)
                        .progressViewStyle(.linear)
                        .tint(top.utilization >= 100 ? .green : .accentColor)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // 겹쳐 띄운다. 줄로 끼워 넣으면 열고 닫을 때마다 아래 화면이 통째로 위아래로 밀린다.
        .overlay(alignment: .topLeading) { rateHelp }
    }

    /// 모은 카드의 값. 잔액 옆에 둔다 — 쓸 수 있는 돈과 쌓아 둔 값은 나란히 읽어야
    /// 뜻이 생기고, 탭 안에 두면 정작 카드를 볼 자리를 그만큼 잡아먹는다.
    @ViewBuilder
    private var collectionWorth: some View {
        if let prices = CardPrices.shared, wallet.distinctCardCount > 0 {
            // 머리글에서는 원화만 쓴다. 달러까지 붙이면 잔액과 나란히 놓기에 너무 길다 —
            // 달러는 카드 상세에서 보면 된다.
            headerStat(l.collectionValue,
                       WonFormatter.money(prices.krw(wallet.currentCollectionValueUSD()),
                                          language: wallet.language),
                       tint: .accentColor)
                .help(l.mixedPriceSource)
        }
    }

    /// 머리글 숫자 한 칸이 쓰는 폭.
    ///
    /// 내용에 맞춰 늘어나게 두면 잔액의 자릿수가 바뀔 때마다 옆 칸이 따라 움직여 두 칸의
    /// 왼쪽 선이 맞지 않는다. 폭을 못 박아 두 칸을 같은 자리에서 시작시킨다 —
    /// 9자리 금액(17pt 기준 약 117pt)까지 들어간다.
    private static let statWidth: CGFloat = 124

    /// 머리글의 숫자 한 칸. 이름과 숫자가 늘 같은 글꼴·같은 간격·같은 폭으로 쌓인다.
    private func headerStat(_ label: String, _ value: String, tint: Color?,
                            hint: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(label)
                    .font(Typography.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
                // 물음표가 있는 칸에만 그리되 **자리는 두 칸 모두 잡는다.**
                //
                // 물음표는 13pt 글리프에 여백까지 붙어 이름줄보다 높다. 한쪽에만 넣으면
                // 그 칸의 이름줄이 그만큼 두꺼워져 아래 숫자줄이 밀리고, 두 금액의 밑선이
                // 어긋난다 — 잔액이 컬렉션 가치보다 몇 pt 내려가 보인 것이 이것이다.
                //
                // 버튼이 아니다. 마우스를 올리면 뜨고 떼면 사라지므로 누를 것이 없다.
                // 화면을 읽어 주는 경로에는 안내 문구 자체를 이름으로 달아 둔다.
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(hoveringRate ? Color.accentColor : .secondary)
                    // 13pt 글리프만 감지 영역으로 두면 겨냥하기 어렵다. 여백까지 넓힌다.
                    .padding(3)
                    .contentShape(Rectangle())
                    .onHover { if hint { hoveringRate = $0 } }
                    .opacity(hint ? 1 : 0)
                    .allowsHitTesting(hint)
                    .accessibilityHidden(!hint)
                    .accessibilityLabel(rateText ?? l.walletRateTitle)
            }
            Text(value)
                .font(Typography.amount).monospacedDigit()
                .foregroundStyle(tint ?? .primary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(width: Self.statWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 토큰 100만 개가 얼마인가.
    ///
    /// 잔액과 팩값을 원으로 보여 주는데 실제로 모으는 것은 토큰이다. 그 환산을 어디에도
    /// 적지 않으면 원 표기가 어디서 나온 값인지 알 수 없다. 토큰 한 개는 5원도 안 되어
    /// 그대로 적으면 감이 오지 않아 100만 개를 기준으로 적는다.
    ///
    /// 끝자리를 끊지 않는다. 환산을 알려 주는 자리에서 반올림한 값을 적으면 그 값이
    /// 어디서 나왔는지 되짚을 수가 없다.
    private var rateText: String? {
        guard let prices = CardPrices.shared else { return nil }
        let sample = 1_000_000
        return l.walletRateBody(
            TokenFormatter.grouped(sample),
            WonFormatter.exact(MarketEconomy.won(tokens: sample, prices: prices),
                               language: wallet.language))
    }

    /// 환산 안내. 물음표에 마우스를 올리면 뜨고, 떼면 사라진다.
    ///
    /// **머리글 위에 겹쳐 띄운다.** 줄로 끼워 넣으면 뜰 때마다 탭과 카드 격자까지 아래로
    /// 밀려 화면이 덜컹거린다. 겹치면 자리를 차지하지 않으므로 아무것도 움직이지 않는다.
    @ViewBuilder
    private var rateHelp: some View {
        if hoveringRate, let text = rateText {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14)).foregroundStyle(Color.accentColor)
                Text(text)
                    .font(Typography.labelSemibold).monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.vertical, 6).padding(.horizontal, 9)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            // 숫자 두 줄 밑으로 내린다. 위로 붙이면 정작 묻고 있는 금액을 가린다.
            .offset(x: 8, y: 52)
            // 마우스를 스쳐도 깜빡이지 않게 아주 짧게 페이드한다.
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
            // 안내가 마우스를 가로채면 뜨는 순간 hover 가 풀려 다시 사라진다.
            .allowsHitTesting(false)
        }
    }

    /// 가장 많이 찬 한도 창. 보너스 팩이 여기서 나오므로 진행률을 보여 준다.
    private var topWindow: BonusWindow? {
        store.bonusEligibleWindows.max { $0.utilization < $1.utilization }
    }

    /// 한 번만 주는 보상 안내. 받은 것을 숫자로 적고, 닫으면 사라진다.
    @ViewBuilder
    private var giftToast: some View {
        if let gift = wallet.lastGift {
            HStack(spacing: 7) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.giftTitle(gift.kind)).font(Typography.bodySemibold)
                    Text(l.giftBody(gift.kind,
                                    packs: gift.packsPerSet * (Self.index?.setIDs.count ?? 0),
                                    money: MarketEconomy.money(tokens: gift.tokens,
                                                               language: wallet.language)))
                        .font(Typography.label).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    wallet.consumeGift()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// 보너스 팩 지급 알림. 팝오버 안에서 한 번 보여주고 지운다.
    @ViewBuilder
    private var bonusToast: some View {
        if let grant = wallet.lastGrant {
            let setName = Self.index?.set(grant.setID)?.name ?? grant.setID
            HStack(spacing: 7) {
                Image(systemName: "gift.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.bonusPackTitle).font(Typography.bodySemibold)
                    Text(l.bonusPackBody(window: grant.windowName, set: setName, count: grant.count))
                        .font(Typography.label).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    wallet.consumeGrant()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.green.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// 업데이트 안내. 새 버전으로 처음 열었을 때 한 줄만 띄우고, 보거나 닫으면 사라진다.
    @ViewBuilder
    private var releaseNotesToast: some View {
        if let version = ReleaseNotes.runningVersion,
           store.lastSeenReleaseVersion != version,
           l.releaseNotes.contains(where: { $0.version == version }) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                Text(l.releaseNotesWhatsNew(version))
                    .font(Typography.bodySemibold)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button(l.releaseNotesOpen) { nav.showReleaseNotes = true }
                    .buttonStyle(.borderless).font(Typography.button)
                Button {
                    store.lastSeenReleaseVersion = version
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14))
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: 첫 실행 안내

    /// 닫았는가. 한 번 닫으면 다시 띄우지 않는다.
    @AppStorage("onboardingDismissed") private var onboardingDismissed = false

    /// 처음 연 사람에게 이 앱이 무엇을 하는지 세 줄로 알린다.
    ///
    /// 예전에는 잔액과 탭만 보여서, 토큰이 어디서 생기고 무엇에 쓰는지 직접 눌러 보며
    /// 알아내야 했다. 카드를 한 장이라도 모았으면 이미 아는 사람이라 띄우지 않는다 —
    /// 업데이트로 이 안내가 생겨도 쓰던 사람에게는 나타나지 않는다.
    @ViewBuilder
    private var onboardingCard: some View {
        if !onboardingDismissed, wallet.distinctCardCount == 0 {
            VStack(alignment: .leading, spacing: 7) {
                Text(l.onboardingTitle).font(Typography.bodySemibold)
                onboardingStep("bolt.fill", l.onboardingEarn)
                onboardingStep("cart.fill", l.onboardingBuy)
                onboardingStep("rectangle.stack.fill", l.onboardingOpen)
                Button(l.onboardingStart) { onboardingDismissed = true }
                    .buttonStyle(.borderedProminent)
                    .font(Typography.button)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func onboardingStep(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            Text(text)
                .font(Typography.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 탭

    /// 탭 줄. `SegmentedTabs` 로 직접 그린다 — 기본 세그먼트 컨트롤은 OS 판에 따라 제 내용
    /// 크기로 줄어들고, macOS 26 에서 네 탭이 창 한가운데로 몰렸다.
    /// 탭 줄의 자리. 산 팩이 날아갈 곳을 여기서 셈한다.
    @State private var tabBarFrame: CGRect = .zero

    /// 「팩」 칸의 가운데. 칸은 폭을 똑같이 나눠 가지므로 순서로 셈한다.
    private var packsTabCenter: CGPoint {
        let tabs = Double(PopoverTab.allCases.count)
        let position = Double(PopoverTab.allCases.firstIndex(of: .packs) ?? 1) + 0.5
        return CGPoint(x: tabBarFrame.minX + tabBarFrame.width * position / tabs,
                       y: tabBarFrame.midY)
    }

    private var tabPicker: some View {
        @Bindable var nav = nav
        return SegmentedTabs(items: [
            .init(value: PopoverTab.shop, label: l.shop),
            .init(value: PopoverTab.packs, label: packsLabel),
            .init(value: PopoverTab.collection, label: l.collection),
            .init(value: PopoverTab.dex, label: l.dexTab),
            .init(value: PopoverTab.stats, label: l.statsTab),
        ], selection: $nav.tab)
    }

    /// 미개봉 팩이 있으면 개수를 붙인다 — 뜯을 것이 있는지 탭을 열지 않고 알 수 있어야 한다.
    private var packsLabel: String {
        let count = wallet.totalPackCount
        return count > 0 ? "\(l.packsTab) \(count)" : l.packsTab
    }

    @ViewBuilder
    private var tabContent: some View {
        switch nav.tab {
        case .shop:       CardShopView(wallet: wallet, index: Self.index)
        case .packs:      PacksView(wallet: wallet, index: Self.index)
        case .collection: CardCollectionView(wallet: wallet, index: Self.index)
        case .dex:        DexView(wallet: wallet, index: Self.index)
        case .stats:      StatsView(wallet: wallet, index: Self.index)
        }
    }
}

/// 온라인 입구 줄의 바탕. 가만히 있을 때도 눌러지는 자리임이 보이고, 올리거나 누르면 짙어진다.
private struct OnlineEntryButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.22 : hovering ? 0.16 : 0.10),
                        in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
