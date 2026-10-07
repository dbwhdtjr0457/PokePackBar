import AppKit
import SwiftUI

@MainActor
final class OnlineWindow: NSObject, NSWindowDelegate {
    static let shared = OnlineWindow()
    private var window: NSWindow?
    private var model: OnlineHubModel?

    /// `section` 이 있으면 그 탭으로 연다. 메뉴바의 교환 제안이나 알림 개수를 눌렀을 때 쓴다.
    func show(wallet: WalletStore, section: String? = nil) {
        if let window {
            if let section, model?.section != section { model?.section = section }
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model?.visible = true; return
        }
        let model = OnlineHubModel(wallet: wallet)
        if let section { model.section = section }
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PokePackBar 온라인"
        window.minSize = NSSize(width: 740, height: 540)
        window.contentView = NSHostingView(rootView: OnlineHubView(model: model))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        model.visible = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { model?.visible = false }
    func windowDidMiniaturize(_ notification: Notification) { model?.visible = false }
    func windowDidDeminiaturize(_ notification: Notification) { model?.visible = true }
}

@MainActor @Observable
final class OnlineHubModel {
    enum Phase { case idle, loading, ready, failed(String) }
    let wallet: WalletStore
    var visible = false
    var phase: Phase = .idle
    /// 마지막 실패 그대로. 배너가 종류와 요청 번호를 고를 때 쓴다.
    var failure: (any Error)?
    var data: [String: Any] = [:]
    var period = 0
    var mode = ""
    var setID = ""
    /// 화면 키는 서버 조회 분기와 레이아웃 감사가 쓰므로 그대로 두고, 보이는 이름만 바꾼다.
    var section = "마켓"
    var message: String?
    var documents: [String: [String: Any]] = [:]
    var generation = 0
    var offset = 0
    var search = ""
    var selectedFriend = ""
    var mutating = false
    var marketSet = ""
    var marketTier = ""
    var marketFinish = ""
    var marketSort = "newest"
    var ownListings = false
    var tradeDraft: [String: Any]?
    var openingJobs: [RemoteGameSession.OpeningJob] = []
    var stopOpening = false
    var openingProgress: String?
    private var refreshAgain = false
    private var refreshAgainFull = false
    init(wallet: WalletStore) { self.wallet = wallet }
    var remote: RemoteGameSession? { wallet.remote }
    /// 다시 불러오는 동안에도 마지막 실패 안내를 그대로 둔다. 15초마다 사라졌다 다시 뜨면
    /// 연결이 끊겼다 붙는 것처럼 보인다. 성공하면 `failure` 가 비워지며 사라진다.
    var errorText: String? {
        if case .failed(let text) = phase { return text }
        if case .loading = phase, let failure { return failure.localizedDescription }
        return nil
    }
    var loading: Bool { if case .loading = phase { return true }; return false }
    var canWrite: Bool {
        guard case .ready = phase else { return false }
        return remote?.ready == true && !wallet.resourceActionsDisabled && !mutating
    }

    enum Connection { case connected, checking, unreachable, serverProblem, signedOut }

    /// 머리글의 연결 표시. 탭 데이터를 불러오는 중이거나 한 요청이 서버 오류로 실패했다고
    /// 연결이 끊긴 것은 아니다. 로그인 세션과 서버에 닿았는지만 본다.
    var connection: Connection {
        guard let remote, !remote.authenticationExpired else { return .signedOut }
        if failure is ServerUnreachable || remote.lastFailure is ServerUnreachable { return .unreachable }
        if remote.ready { return .connected }
        return remote.lastFailure == nil ? .checking : .serverProblem
    }

    /// `full` 이 아니면 지금 탭에 필요한 것만 받는다. 계정 동기화는 앱이 10초마다 따로 하므로
    /// 탭을 옮기거나 거를 때마다 다시 할 필요가 없다. 창을 열 때, 주기 갱신, 새로고침, 거래 뒤에만
    /// 동기화와 서버 상태, 프로필까지 함께 받는다.
    /// `force` 는 사용자가 누른 다시 시도와 새로고침이다. 끊긴 동안 자동 갱신은 재연결 간격을 지킨다.
    func refresh(full: Bool = true, force: Bool = false) async {
        guard !loading, !mutating else {
            refreshAgain = true
            refreshAgainFull = refreshAgainFull || full
            return
        }
        guard let remote else {
            failure = OnlineSignedOut()
            phase = .failed("이 Mac은 아직 로컬 모드예요. 로그인하고 온라인 모드를 켜면 마켓, 교환, 친구를 쓸 수 있어요.")
            return
        }
        phase = .loading
        do {
            if full || !remote.ready { await remote.synchronize(force: force) }
            guard remote.ready else {
                throw remote.lastFailure ?? RemoteGameSession.Failure(message: remote.error ?? "로그인이 필요합니다.")
            }
            if full || documents["server"] == nil { documents["server"] = try await read("v1/server/status") }
            let currentSection = section
            if currentSection == "작업" {
                struct Jobs: Decodable { let items: [RemoteGameSession.OpeningJob] }
                openingJobs = try JSONDecoder().decode(Jobs.self, from: await remote.api("v1/opening-jobs?offset=\(offset)")).items
            }
            if currentSection == "통계" {
                var query = "v1/stats?days=\(period)"
                if !mode.isEmpty { query += "&mode=\(mode)" }
                if !setID.isEmpty { query += "&set_id=\(setID)" }
                data = try await read(query)
            } else {
                if full || documents["profile"] == nil { documents["profile"] = try await read("v1/profile") }
                if currentSection == "컬렉션·친구" {
                    documents["friends"] = try await read("v1/friends?offset=\(offset)")
                    documents["inventory"] = try await read("v1/inventory?q=\(escaped(search))&offset=\(offset)")
                    documents["blocks"] = try await read("v1/blocks?offset=\(offset)")
                    documents["matches"] = try await read("v1/matches?offset=\(offset)")
                    if !selectedFriend.isEmpty {
                        do { documents["friend"] = try await read("v1/friends/\(selectedFriend)") }
                        catch let error as RemoteGameSession.Failure {
                            if [403, 404].contains(error.status ?? 0) {
                                selectedFriend = ""; documents["friend"] = nil; documents["friendInventory"] = nil
                            } else { throw error }
                        }
                    }
                } else if currentSection == "알림" {
                    documents["notifications"] = try await read("v1/notifications?after=\(offset)")
                } else if currentSection == "교환" {
                    documents["trades"] = try await read("v1/trades?offset=\(offset)")
                    documents["friends"] = try await read("v1/friends?limit=100")
                    documents["matches"] = try await read("v1/matches?limit=100")
                } else if currentSection == "마켓" {
                    documents["listings"] = try await read("v1/market/listings?q=\(escaped(search))&set_id=\(escaped(marketSet))&tier=\(escaped(marketTier))&finish=\(escaped(marketFinish))&sort=\(marketSort)&mine=\(ownListings)&offset=\(offset)")
                }
            }
            generation += 1
            phase = .ready
            failure = nil
        } catch {
            if remote.authenticationExpired { clearPrivateData() }
            fail(error, while: "\(section) 불러오기")
        }
        if refreshAgain {
            let again = refreshAgainFull
            refreshAgain = false
            refreshAgainFull = false
            await refresh(full: again)
        }
    }

    func clearPrivateData() {
        data = [:]; documents = [:]; selectedFriend = ""; tradeDraft = nil; message = nil
        openingJobs = []; openingProgress = nil; stopOpening = true
    }

    func read(_ path: String) async throws -> [String: Any] {
        guard let remote else { throw RemoteGameSession.Failure(message: "온라인 로그인이 필요합니다.") }
        return try JSONSerialization.jsonObject(with: await remote.api(path)) as? [String: Any] ?? [:]
    }
    func escaped(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }
    func items(_ key: String) -> [[String: Any]] { documents[key]?["items"] as? [[String: Any]] ?? [] }
    var profile: [String: Any] { documents["profile"]?["profile"] as? [String: Any] ?? [:] }

    /// 성공하면 true. 화면은 성공했을 때만 입력(교환 바구니 등)을 비운다.
    @discardableResult
    func mutate(_ route: String, _ values: [String: Any]) async -> Bool {
        guard canWrite, let remote else { return false }
        mutating = true
        do {
            let body = values.merging(["request_id": UUID().uuidString, "expected_revision": remote.revision]) { _, right in right }
            _ = try await remote.onlineMutation(path: "v1/\(route)", body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
            message = "완료했어요."
            mutating = false
            await refresh()
            // 수락, 거절, 읽음 처리 뒤 메뉴바 개수가 1분 동안 남아 있지 않게 바로 갱신한다.
            await remote.refreshNotificationSummary()
            return true
        } catch {
            mutating = false
            fail(error, while: route)
            return false
        }
    }

    /// 서버 요청 실패는 전송 단계에서 이미 로그에 남는다. 응답은 받았지만 읽지 못한 경우
    /// (형식이 바뀐 응답 등)는 여기서만 보이므로 따로 남긴다.
    private func fail(_ error: any Error, while action: String) {
        let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
        if !(error is any ServerTraceable), !cancelled {
            AppLog.write("[online] \(action) failed: \(String(describing: error).prefix(400))")
        }
        failure = error
        phase = .failed(error.localizedDescription)
    }

    func resumeOpening(_ initial: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true; stopOpening = false
        var job = initial
        do {
            while job.status == "active", visible, !stopOpening, !Task.isCancelled {
                openingProgress = "\(job.total.formatted())팩 중 \(job.completed.formatted())팩 열었어요"
                job = try await remote.advanceOpeningJob(job).job
            }
            message = "\(job.total.formatted())팩 중 \(job.completed.formatted())팩을 열었어요. 나온 카드는 컬렉션에서 볼 수 있어요."
        } catch { message = error.localizedDescription }
        mutating = false; openingProgress = nil
        if visible { await refresh() }
    }

    func cancelOpening(_ job: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true
        do { _ = try await remote.advanceOpeningJob(job, cancel: true); message = "남은 팩은 열지 않기로 했어요. 이미 연 카드는 그대로 있어요." }
        catch { message = error.localizedDescription }
        mutating = false
        await refresh()
    }
}

@MainActor
struct OnlineHubView: View {
    @Bindable var model: OnlineHubModel

    /// 화면 키 -> 보이는 이름. 자주 쓰는 순서로 둔다.
    private static let sections: [(key: String, title: String)] = [
        ("마켓", "마켓"), ("교환", "교환"), ("컬렉션·친구", "친구"),
        ("통계", "개봉 분석"), ("작업", "대량 개봉"), ("알림", "알림"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let error = model.errorText {
                OnlineFailureBanner(problem: OnlineProblem(model.failure), message: error,
                                    loading: model.loading, retryAt: model.remote?.retryAt,
                                    signIn: { AccountWindow.shared.show(wallet: model.wallet) }) { reload(full: true, force: true) }
            }
            if let jobs = model.documents["server"]?["jobs"] as? [[String: Any]],
               jobs.contains(where: { ["failed", "stale"].contains($0["state"] as? String ?? "") }) {
                Label("서버 자동 작업에 문제가 있어요. 「계정」에서 확인해 주세요.", systemImage: "exclamationmark.triangle")
                    .font(Typography.label).foregroundStyle(.orange)
            }
            Picker("", selection: $model.section) {
                ForEach(Self.sections, id: \.key) { Text($0.title).tag($0.key) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .onChange(of: model.section) { model.offset = 0; model.message = nil; reload() }
            if let message = model.message {
                Label(message, systemImage: "checkmark.circle").font(Typography.label).foregroundStyle(.secondary)
            }
            if model.remote?.authenticationExpired == true {
                VStack(spacing: 12) {
                    OnlineEmptyState(icon: "lock", title: "다시 로그인해 주세요",
                                     message: "로그인이 만료돼서 이 화면을 비웠어요. 같은 계정으로 다시 로그인하면 처리 중이던 요청도 이어서 확인해요.")
                    Button("로그인하기") { AccountWindow.shared.show(wallet: model.wallet) }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
            else if model.section == "통계" { statistics }
            else if model.section == "컬렉션·친구" { OnlineSocialView(model: model) }
            else if model.section == "교환" { OnlineTradingView(model: model) }
            else if model.section == "마켓" { OnlineMarketView(model: model) }
            else if model.section == "작업" { openingWork }
            else { notifications }
        }
        .padding(22)
        .onChange(of: model.remote?.authenticationExpired) {
            if model.remote?.authenticationExpired == true { model.clearPrivateData() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: model.visible) {
            guard model.visible else { return }
            while !Task.isCancelled && model.visible {
                await model.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    // MARK: 머리글

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("온라인").font(Typography.display)
                HStack(spacing: 6) {
                    Circle().fill(connectionStatus.color).frame(width: 7, height: 7)
                    Text(connectionStatus.text)
                    if let status = model.remote?.priceStatus, let last = status.last_success {
                        Text("시세 \(Date(timeIntervalSince1970: Double(last)).formatted(date: .abbreviated, time: .omitted)) 기준")
                            .padding(.leading, 6)
                    }
                }
                .font(Typography.label).foregroundStyle(.secondary)
            }
            Spacer()
            Text("쓸 수 있는 금액 \(OnlineText.won(tokens: model.wallet.availableTokens))")
                .font(Typography.bodySemibold).monospacedDigit()
            if model.loading { ProgressView().controlSize(.small) }
            Button { reload(full: true, force: true) } label: { Image(systemName: "arrow.clockwise") }
                .help("새로고침").disabled(model.loading)
            Button { AccountWindow.shared.show(wallet: model.wallet) } label: { Image(systemName: "person.crop.circle") }
                .help("계정과 서버")
        }
    }

    private var connectionStatus: (text: String, color: Color) {
        switch model.connection {
        case .connected:
            let nickname = model.profile.string("nickname")
            return (nickname.isEmpty ? "연결됨" : nickname, .green)
        case .checking: return ("연결 확인 중", .secondary)
        case .unreachable: return ("연결 안 됨", .orange)
        case .serverProblem: return ("서버 오류", .orange)
        case .signedOut: return ("로그인 필요", .secondary)
        }
    }

    // MARK: 알림

    private var notifications: some View {
        let items = model.items("notifications")
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    OnlineEmptyState(icon: "bell", title: "새 알림이 없어요",
                                     message: "친구 신청, 교환 제안, 마켓 판매 소식이 여기에 와요.")
                }
                ForEach(items, id: \.onlineID) { item in
                    let info = OnlineText.notification(item.string("kind"))
                    let unread = !item.bool("read")
                    HStack(spacing: 12) {
                        Image(systemName: info.icon).font(.system(size: 17))
                            .foregroundStyle(unread ? Color.accentColor : Color.secondary).frame(width: 24)
                        Text(info.text).font(unread ? Typography.bodySemibold : Typography.body)
                        Spacer()
                        if unread {
                            Button("확인") {
                                Task { await model.mutate("notifications", ["action": "notification_read", "notification_id": item.int("id")]) }
                            }
                            .disabled(!model.canWrite)
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(unread ? Color.accentColor.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                HStack {
                    if model.offset > 0 { Button("처음으로") { model.offset = 0; reload() } }
                    if let next = model.documents["notifications"]?["next_after"] as? Int {
                        Button("더 보기") { model.offset = next; reload() }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 대량 개봉

    private var openingWork: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("1,000팩이 넘는 개봉은 여기서 나눠서 이어 열어요. 창을 닫거나 멈추면 지금 묶음까지만 열고 멈춰요. 다른 기기에서 팩을 쓰면 이어 열기가 멈출 수 있어요.")
                    .font(Typography.label).foregroundStyle(.secondary)
                if let progress = model.openingProgress {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(progress).monospacedDigit()
                        Spacer()
                        Button("이번 묶음까지만 열기") { model.stopOpening = true }
                            .disabled(model.stopOpening)
                    }
                }
                if model.openingJobs.isEmpty {
                    OnlineEmptyState(icon: "shippingbox", title: "이어서 열 팩이 없어요",
                                     message: "한 번에 1,000팩 넘게 열면 여기서 이어 열 수 있어요.")
                }
                ForEach(model.openingJobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(CardIndex.shared?.set(job.set_id)?.name ?? job.set_id).font(Typography.bodySemibold)
                            OnlineBadge(text: job.status == "completed" ? "다 열었어요" : job.status == "cancelled" ? "그만둠" : "이어 열 수 있어요",
                                        color: job.status == "active" ? .accentColor : .secondary)
                            Spacer()
                            Text(job.opening_mode == "game" ? "게임 모드" : "실물 모드")
                                .font(Typography.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(job.completed), total: Double(job.total))
                        Text("\(job.total.formatted())팩 중 \(job.completed.formatted())팩 열었어요")
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                        if job.status == "active" {
                            HStack {
                                Spacer()
                                Button("남은 팩 그만 열기", role: .destructive) { Task { await model.cancelOpening(job) } }
                                Button("이어서 열기") { Task { await model.resumeOpening(job) } }
                                    .buttonStyle(.borderedProminent)
                            }
                            .disabled(!model.canWrite)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                if model.offset > 0 || model.openingJobs.count >= 25 {
                    HStack {
                        Button("이전") { model.offset = max(0, model.offset - 25); reload() }.disabled(model.offset == 0 || model.mutating)
                        Button("다음") { model.offset += 25; reload() }.disabled(model.openingJobs.count < 25 || model.mutating)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: 통계

    private var statistics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 메뉴바의 「통계」 탭(이 계정 전체 요약)과 이름이 같아 무엇이 다른지 헷갈렸다.
                Text("서버에 기록된 개봉 결과를 기간, 모드, 세트별로 나눠 봐요. 보유 카드와 컬렉션 전체 요약은 메뉴바의 「통계」 탭에 있어요.")
                    .font(Typography.label).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    // 고정 폭을 주면 세그먼트가 그 안 가운데로 가서 다른 줄과 왼쪽 선이 어긋났다.
                    Picker("기간", selection: $model.period) { Text("전체 기간").tag(0); Text("최근 7일").tag(7); Text("최근 30일").tag(30) }
                        .pickerStyle(.segmented).fixedSize()
                    Picker("모드", selection: $model.mode) { Text("모든 모드").tag(""); Text("게임 모드").tag("game"); Text("실물 모드").tag("realistic") }
                        .fixedSize()
                    Picker("세트", selection: $model.setID) {
                        Text("모든 세트").tag("")
                        ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .fixedSize()
                }
                .labelsHidden()
                .onChange(of: model.period) { reload() }.onChange(of: model.mode) { reload() }.onChange(of: model.setID) { reload() }

                if let totals = model.data["totals"] as? [String: Any], !totals.isEmpty {
                    let number = { (key: String) in (totals[key] as? NSNumber)?.intValue ?? 0 }
                    // 여섯 칸을 3칸씩 두 줄로. 폭에 맞춰 늘리면 넓은 창에서 5칸과 1칸으로 갈라졌다.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        statTile("연 팩", number("opened").formatted() + "팩")
                        statTile("산 팩", number("purchased").formatted() + "팩")
                        statTile("새로 얻은 카드", number("new").formatted() + "장")
                        statTile("겹친 카드", number("duplicates").formatted() + "장")
                        statTile("팩 사는 데 쓴 돈", OnlineText.won(tokens: number("purchase_spent")))
                        statTile("카드 팔아 번 돈", OnlineText.won(tokens: number("sale_income")))
                    }
                    if let value = model.data["collection_usd"] as? Double, let prices = CardPrices.shared {
                        Text("지금 컬렉션을 시세로 치면 \(prices.formattedWithKRW(value, language: .ko))예요.")
                            .font(Typography.body)
                    }
                    if let rate = model.data["new_rate"] as? Double {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("새 카드가 나온 비율 \(Int((rate * 100).rounded()))%").font(Typography.labelSemibold)
                            ProgressView(value: rate).tint(.accentColor)
                        }
                    }
                    HStack(alignment: .top, spacing: 28) {
                        breakdown("등급별로 나온 카드", model.data["tiers"] as? [String: Int] ?? [:]) { raw in
                            CardTier(rawValue: raw).map { "\($0.rawValue) \(OnlineText.l.tierName($0))" } ?? raw
                        } order: { raw in -(CardTier(rawValue: raw)?.rank ?? 0) }
                        breakdown("판형별로 나온 카드", model.data["finishes"] as? [String: Int] ?? [:]) { raw in
                            OnlineText.finish(raw)
                        } order: { _ in 0 }
                        breakdown("팩 종류", model.data["variants"] as? [String: Int] ?? [:], unit: "팩") { raw in
                            switch raw {
                            case "standard", "celebrations": return "일반 팩"
                            case "god": return "갓팩"
                            case "demigod": return "준갓팩"
                            default:
                                guard let variant = PackVariant(rawValue: raw) else { return raw }
                                let badge = OnlineText.l.specialPackBadge(variant)
                                return badge.isEmpty ? "일반 팩" : badge
                            }
                        } order: { raw in raw == "standard" ? 0 : 1 }
                    }
                    Text("실제로 나온 결과예요. 앞으로의 확률을 보장하지는 않아요.\((model.data["coverage_since"] as? String).map { " \($0)부터 기록했어요." } ?? "")")
                        .font(Typography.caption).foregroundStyle(.secondary)
                } else {
                    OnlineEmptyState(icon: "chart.bar", title: "아직 기록이 없어요",
                                     message: "온라인 계정으로 팩을 사거나 열면 여기에 쌓여요.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Typography.label).foregroundStyle(.secondary)
            Text(value).font(Typography.heading).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func breakdown(_ title: String, _ counts: [String: Int], unit: String = "장",
                           label: @escaping (String) -> String, order: (String) -> Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typography.labelSemibold)
            let keys = counts.keys.sorted { (order($0), -(counts[$0] ?? 0), $0) < (order($1), -(counts[$1] ?? 0), $1) }
            if keys.isEmpty { Text("없음").font(Typography.label).foregroundStyle(.secondary) }
            ForEach(keys, id: \.self) { key in
                HStack {
                    Text(label(key)).font(Typography.label)
                    Spacer(minLength: 12)
                    Text("\((counts[key] ?? 0).formatted())\(unit)").font(Typography.label).monospacedDigit()
                }
            }
        }
        .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
    }

    /// 탭 이동, 필터, 쪽 넘기기는 그 탭만. 새로고침 버튼과 다시 시도는 전체.
    private func reload(full: Bool = false, force: Bool = false) { Task { await model.refresh(full: full, force: force) } }
}

extension Dictionary where Key == String, Value == Any {
    var onlineID: String { string("id") + ":" + string("printing") + ":" + string("public_id") }
    func string(_ key: String) -> String { self[key] as? String ?? (self[key] as? NSNumber)?.stringValue ?? "" }
    func int(_ key: String) -> Int { (self[key] as? NSNumber)?.intValue ?? 0 }
    func bool(_ key: String) -> Bool { self[key] as? Bool ?? false }
}
