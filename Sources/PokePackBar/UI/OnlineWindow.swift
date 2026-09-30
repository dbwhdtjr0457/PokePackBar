import AppKit
import SwiftUI

@MainActor
final class OnlineWindow: NSObject, NSWindowDelegate {
    static let shared = OnlineWindow()
    private var window: NSWindow?
    private var model: OnlineHubModel?

    func show(wallet: WalletStore) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model?.visible = true; return }
        let model = OnlineHubModel(wallet: wallet)
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PPB 온라인"
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
    var data: [String: Any] = [:]
    var period = 0
    var mode = ""
    var setID = ""
    var section = "통계"
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
    init(wallet: WalletStore) { self.wallet = wallet }
    var remote: RemoteGameSession? { wallet.remote }
    var errorText: String? { if case .failed(let text) = phase { return text }; return nil }
    var loading: Bool { if case .loading = phase { return true }; return false }
    var canWrite: Bool {
        guard case .ready = phase else { return false }
        return remote?.ready == true && !wallet.resourceActionsDisabled && !mutating
    }

    func refresh() async {
        guard !loading, !mutating else { refreshAgain = true; return }
        guard let remote else { phase = .failed("로컬 모드입니다. 메뉴바 설정에서 로그인한 뒤 앱을 재시작하세요."); return }
        phase = .loading
        do {
            await remote.synchronize()
            guard remote.ready else { throw RemoteGameSession.Failure(message: remote.error ?? "로그인이 필요합니다.") }
            documents["server"] = try await read("v1/server/status")
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
                documents["profile"] = try await read("v1/profile")
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
        } catch {
            if remote.authenticationExpired { clearPrivateData() }
            phase = .failed(error.localizedDescription)
        }
        if refreshAgain { refreshAgain = false; await refresh() }
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

    func mutate(_ route: String, _ values: [String: Any]) async {
        guard canWrite, let remote else { return }
        mutating = true
        do {
            let body = values.merging(["request_id": UUID().uuidString, "expected_revision": remote.revision]) { _, right in right }
            _ = try await remote.onlineMutation(path: "v1/\(route)", body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
            message = "처리 완료 · 서버에 저장했습니다."
            mutating = false
            await refresh()
        } catch {
            mutating = false
            phase = .failed(error.localizedDescription)
        }
    }

    func resumeOpening(_ initial: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true; stopOpening = false
        var job = initial
        do {
            while job.status == "active", visible, !stopOpening, !Task.isCancelled {
                openingProgress = "\(job.completed.formatted()) / \(job.total.formatted())팩 완료"
                job = try await remote.advanceOpeningJob(job).job
            }
            message = "\(job.completed.formatted()) / \(job.total.formatted())팩 완료 · 획득 카드는 도감에서 확인하세요."
        } catch { message = error.localizedDescription }
        mutating = false; openingProgress = nil
        if visible { await refresh() }
    }

    func cancelOpening(_ job: RemoteGameSession.OpeningJob) async {
        guard canWrite, let remote else { return }
        mutating = true
        do { _ = try await remote.advanceOpeningJob(job, cancel: true); message = "남은 작업을 취소했습니다. 이미 개봉한 카드는 유지됩니다." }
        catch { message = error.localizedDescription }
        mutating = false
        await refresh()
    }
}

struct OnlineHubView: View {
    @Bindable var model: OnlineHubModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("온라인 컬렉션").font(.title2.bold())
                Spacer()
                Button("계정 및 서버…") { AccountWindow.shared.show(wallet: model.wallet) }
                if model.loading { ProgressView().controlSize(.small) }
                Button("새로고침") { Task { await model.refresh() } }.disabled(model.loading)
            }
            if let error = model.errorText {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled)
                Text("연결 실패 중에는 마지막 조회 내용만 표시하며 거래는 실행하지 않습니다.").font(.caption)
            }
            if let jobs = model.documents["server"]?["jobs"] as? [[String: Any]],
               jobs.contains(where: { ["failed", "stale"].contains($0["state"] as? String ?? "") }) {
                Label("자동 작업에 확인이 필요합니다. ‘계정 및 서버’에서 상태를 확인하세요.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            }
            if let status = model.remote?.priceStatus {
                Text(status.last_success.map { "시세 갱신: \(Date(timeIntervalSince1970: Double($0)).formatted())" }
                    ?? "시세: 기본 스냅샷 · 자동 갱신 대기").font(.caption).foregroundStyle(.secondary)
                if let error = status.error { Text(error).font(.caption).foregroundStyle(.orange) }
                Text("시세 버전: \(model.remote?.priceVersion?.prefix(12) ?? "없음") · TCGplayer / TCGCSV · 항목별 날짜는 카드 상세 참조").font(.caption2).foregroundStyle(.secondary)
            }
            Picker("온라인 기능", selection: $model.section) {
                ForEach(["통계", "컬렉션·친구", "교환", "마켓", "작업", "알림"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).onChange(of: model.section) { model.offset = 0; reload() }
            if let message = model.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if model.remote?.authenticationExpired == true {
                ContentUnavailableView("다시 로그인하세요", systemImage: "lock", description: Text("이전 계정의 온라인 화면을 비웠습니다. 미확인 요청은 같은 계정으로 로그인하면 복구합니다."))
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

    private var notifications: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.items("notifications"), id: \.onlineID) { item in
                    HStack {
                        Text(item.string("kind")); Text(item.string("target")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(item.bool("read") ? "읽음" : "읽음으로 표시") {
                            Task { await model.mutate("notifications", ["action": "notification_read", "notification_id": item.int("id")]) }
                        }.disabled(!model.canWrite || item.bool("read"))
                    }
                }
                if model.items("notifications").isEmpty { Text("새 알림이 없습니다. 친구 요청이나 거래 결과가 여기에 표시됩니다.") }
                if let next = model.documents["notifications"]?["next_after"] as? Int {
                    Button("다음 알림") { model.offset = next; reload() }
                }
                if model.offset > 0 { Button("처음으로") { model.offset = 0; reload() } }
            }
        }
    }

    private var openingWork: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("대량 개봉 이어하기").font(.headline)
                Text("1,000팩을 넘는 개봉의 진행 상황입니다. 창을 닫거나 일시정지하면 현재 묶음까지만 처리합니다. 팩을 예약하지 않으므로 다른 기기에서 소비하면 이어하기가 중단될 수 있습니다.")
                    .font(.callout).foregroundStyle(.secondary)
                if let progress = model.openingProgress {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(progress).monospacedDigit()
                        Spacer()
                        Button("다음 묶음부터 일시정지") { model.stopOpening = true }
                            .disabled(model.stopOpening)
                    }
                }
                ForEach(model.openingJobs) { job in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(CardIndex.shared?.set(job.set_id)?.name ?? job.set_id).font(.headline)
                                Spacer()
                                Text(job.status == "completed" ? "완료" : job.status == "cancelled" ? "취소됨" : "이어가기 가능")
                            }
                            ProgressView(value: Double(job.completed), total: Double(job.total))
                            Text("\(job.completed.formatted()) / \(job.total.formatted())팩 · \(job.opening_mode == "game" ? "게임" : "실물") 모드")
                                .font(.caption).monospacedDigit()
                            if job.status == "active" {
                                HStack {
                                    Button("남은 팩 개봉 계속") { Task { await model.resumeOpening(job) } }
                                        .buttonStyle(.borderedProminent)
                                    Button("남은 작업 취소", role: .destructive) { Task { await model.cancelOpening(job) } }
                                }.disabled(!model.canWrite)
                            }
                        }.padding(8)
                    }
                }
                if model.openingJobs.isEmpty { Text("아직 대량 개봉 작업이 없습니다.").foregroundStyle(.secondary) }
                HStack {
                    Button("이전") { model.offset = max(0, model.offset - 25); reload() }.disabled(model.offset == 0 || model.mutating)
                    Button("다음") { model.offset += 25; reload() }.disabled(model.openingJobs.count < 25 || model.mutating)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("기간", selection: $model.period) { Text("전체").tag(0); Text("7일").tag(7); Text("30일").tag(30) }
                Picker("모드", selection: $model.mode) { Text("전체").tag(""); Text("게임").tag("game"); Text("실물").tag("realistic") }
                Picker("세트", selection: $model.setID) {
                    Text("전체 세트").tag("")
                    ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
                }
            }.onChange(of: model.period) { reload() }.onChange(of: model.mode) { reload() }.onChange(of: model.setID) { reload() }
            if let totals = model.data["totals"] as? [String: Any], !totals.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 36, verticalSpacing: 12) {
                    ForEach([("purchased", "구매 팩"), ("opened", "개봉 팩"), ("purchase_spent", "팩 구매 지출 (토큰)"),
                             ("sale_income", "분해 판매 수입 (토큰)"), ("new", "신규 카드"), ("duplicates", "중복 카드")], id: \.0) { key, label in
                        GridRow { Text(label); Text("\((totals[key] as? NSNumber)?.intValue ?? 0)").monospacedDigit() }
                    }
                }
            } else { ContentUnavailableView("아직 개봉 통계가 없습니다", systemImage: "chart.bar", description: Text("온라인 계정에서 구매하거나 팩을 열면 기록됩니다.")) }
            if let value = model.data["collection_usd"] as? Double { Text("현재 컬렉션 평가액: $\(value, specifier: "%.2f") · 실제 지출/수익과 다릅니다.") }
            if let rate = model.data["new_rate"] as? Double {
                Text("신규 \(rate * 100, specifier: "%.2f")% / 중복 \((1 - rate) * 100, specifier: "%.2f")%").font(.caption)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    breakdown("tiers", "희귀도별 획득")
                    breakdown("finishes", "판형별 획득")
                    breakdown("variants", "팩 변형별 횟수")
                    let rates = model.data["variant_rates"] as? [String: Double] ?? [:]
                    ForEach(rates.keys.sorted(), id: \.self) { key in
                        Text("\(key) 관측 비율: \((rates[key] ?? 0) * 100, specifier: "%.3f")%")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("관측 획득률은 보장 확률이 아닙니다. 과거 자료가 없는 기간은 소급 추정하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            if let since = model.data["coverage_since"] as? String { Text("기록 시작: \(since)").font(.caption) }
        }
    }

    private func breakdown(_ key: String, _ title: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            let counts = model.data[key] as? [String: Int] ?? [:]
            ForEach(counts.keys.sorted(), id: \.self) { name in
                HStack { Text(name); Spacer(); Text("\(counts[name] ?? 0)").monospacedDigit() }
            }
        }
    }
    private func reload() { Task { await model.refresh() } }
}

extension Dictionary where Key == String, Value == Any {
    var onlineID: String { string("id") + ":" + string("printing") + ":" + string("public_id") }
    func string(_ key: String) -> String { self[key] as? String ?? (self[key] as? NSNumber)?.stringValue ?? "" }
    func int(_ key: String) -> Int { (self[key] as? NSNumber)?.intValue ?? 0 }
    func bool(_ key: String) -> Bool { self[key] as? Bool ?? false }
}
