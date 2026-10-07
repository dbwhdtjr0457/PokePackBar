import CryptoKit
import Foundation
import Observation

struct RemoteGameConfiguration: Codable, Sendable {
    let baseURL: URL
    let accountID: UUID
    let deviceID: UUID

    @MainActor static var requested: Bool {
        ProcessInfo.processInfo.environment["PPB_SERVER_URL"] != nil
            || UserDefaults.standard.bool(forKey: "ppb.server.enabled")
    }

    @MainActor static func load() -> Self? {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let url = env["PPB_SERVER_URL"] ?? defaults.string(forKey: "ppb.server.url") ?? ""
        let account = env["PPB_SERVER_ACCOUNT_ID"] ?? defaults.string(forKey: "ppb.server.account") ?? ""
        guard env["PPB_SERVER_URL"] != nil || defaults.bool(forKey: "ppb.server.enabled"),
              let baseURL = URL(string: url), let accountID = UUID(uuidString: account),
              validURL(baseURL) else { return nil }
        let device: UUID
        if let saved = UUID(uuidString: env["PPB_SERVER_DEVICE_ID"]
            ?? defaults.string(forKey: "ppb.server.device") ?? "") { device = saved }
        else {
            device = UUID()
            defaults.set(device.uuidString, forKey: "ppb.server.device")
        }
        return Self(baseURL: baseURL, accountID: accountID, deviceID: device)
    }

    static func validURL(_ url: URL) -> Bool {
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.host != nil else { return false }
        return url.scheme == "https" || (url.scheme == "http"
            && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(url.host ?? ""))
    }

    var storageKey: String {
        // The server tracks cumulative usage by device. Reusing another device's
        // local collector or pending report would credit its historical total again.
        SHA256.hash(data: Data("\(baseURL.absoluteString)/\(accountID)/\(deviceID)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

/// One durable request at a time. Unknown network outcomes retain the SAME ID;
/// reconnect/restart replays it, never redraws an uncertain pack opening.
@MainActor @Observable
final class RemoteGameSession {
    struct Snapshot: Codable {
        let account_id: String
        let revision: Int
        let balance: Int
        let state: GameState
        var reserved: [String: Int]? = nil
        /// 서버가 계산한 공개 상태의 지문. 변경분을 적용하기 전에 같은 상태인지 확인한다.
        var state_digest: String? = nil
    }
    struct Request: Codable {
        let request_id: UUID
        let expected_revision: Int
        let command: ServerRulesBridge.Command
        let rules_version: String
        var price_version: String? = nil
        var quoted_tokens: Int? = nil
    }
    struct Response: Decodable {
        /// 변경분(`snapshot_patch`)으로 온 응답에는 없다.
        let snapshot: Snapshot?
        let result: ServerRulesBridge.Result
        let event_revision: Int
        let replayed: Bool
    }
    struct RuleVersion: Decodable { let rules_version: String }
    struct OpeningJob: Decodable, Identifiable {
        let id: String
        let set_id: String
        let total: Int
        let completed: Int
        let version: Int
        let status: String
        let opening_mode: String
    }
    struct OpeningJobResult: Decodable { let job: OpeningJob; let packs: OpenedPackBatch? }
    struct OpeningJobReply: Decodable { let result: OpeningJobResult }
    struct PriceStatus: Decodable { let version: String?; let last_success: Int?; let error: String? }
    /// 메뉴바에서 온라인 창을 열지 않아도 알 수 있게 하는 개수.
    struct NotificationSummary: Decodable, Equatable {
        let unread: Int
        let incoming_trades: Int
        let incoming_friends: Int
        var isEmpty: Bool { unread == 0 && incoming_trades == 0 && incoming_friends == 0 }
    }
    struct Quote: Decodable { let tokens: Int; let price_version: String?; let revision: Int }
    struct Failure: LocalizedError, ServerTraceable {
        let message: String
        var status: Int? = nil
        /// 서버 로그의 request_id. 서버에 보내기 전에 막힌 실패면 비어 있다.
        var requestID: String? = nil
        var errorDescription: String? { message }
    }

    let configuration: RemoteGameConfiguration
    private(set) var revision = 0
    private(set) var busy = false
    private(set) var ready = false
    private(set) var error: String?
    /// `error` 를 만든 실패 그대로. 화면이 요청 번호와 종류를 보여 줄 때 쓴다.
    private(set) var lastFailure: (any Error)?
    private(set) var hasPending = false
    private(set) var recoveredResult: ServerRulesBridge.Result?
    private(set) var priceVersion: String?
    private(set) var priceStatus: PriceStatus?
    private(set) var notificationSummary: NotificationSummary?
    @ObservationIgnored private var summaryCheckedAt: Date?
    /// 요약 API 가 없는 예전 서버. 매분 404 를 로그에 남기지 않게 한 번 확인하면 더 묻지 않는다.
    @ObservationIgnored private var summaryUnsupported = false
    private(set) var reservedPrintings: [String: Int] = [:]
    private(set) var authenticationExpired = false
    private(set) var hasOnlinePending = false
    private var onlinePendingURL: URL { directory.appendingPathComponent("online-pending.json") }
    struct OnlinePending: Codable { let path: String; let body: Data }
    var awaitingFirstUsage: Bool { collector.awaitingFirstUsage }
    @ObservationIgnored var onSnapshot: ((GameState) -> Void)?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let collector: WalletStore
    @ObservationIgnored private var reportedTokens = 0
    @ObservationIgnored private var acceptedSnapshot = false
    @ObservationIgnored private var lastSnapshot: Snapshot?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let tokenProvider: (() throws -> String?)?
    /// 키체인에서 한 번 읽은 로그인 정보. 요청마다 키체인을 다시 읽지 않는다.
    @ObservationIgnored private var cachedCredential: ServerCredential?
    /// 서버에 연속으로 닿지 못하거나 5xx 를 받은 횟수와, 그다음 동기화를 미룰 시각.
    /// 끊긴 동안 탭을 옮기거나 다시 시도할 때마다 바로 재연결하면 21초에 16번처럼 몰렸다.
    @ObservationIgnored private var failureStreak = 0
    private(set) var retryAt: Date?
    private var pendingURL: URL { directory.appendingPathComponent("pending.json") }
    var cacheURL: URL { directory.appendingPathComponent("game-state.json") }

    init(configuration: RemoteGameConfiguration, localRoot: URL, tokenProvider: (() throws -> String?)? = nil) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        directory = localRoot.appendingPathComponent("online-\(configuration.storageKey)", isDirectory: true)
        collector = WalletStore(fileURL: directory.appendingPathComponent("device-collection.json"))
        hasPending = FileManager.default.fileExists(atPath: directory.appendingPathComponent("pending.json").path)
        hasOnlinePending = FileManager.default.fileExists(atPath: directory.appendingPathComponent("online-pending.json").path)
        let priceCache = directory.appendingPathComponent("prices.json")
        if let data = try? PriceSnapshotStore.read(priceCache) {
            do {
                try PriceSnapshotStore.shared.applyOnline(data, cacheURL: priceCache)
                priceVersion = OpeningRules.digest(data)
            } catch { self.error = "시세 캐시가 손상되어 서버에서 다시 받아야 합니다." }
        }
    }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.synchronize()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func recordUsage(_ providers: [String: Int], date: String, hasData: Bool) {
        collector.update(todayTokensByProvider: providers, todayDate: date, hasUsageData: hasData)
    }

    /// `force` 는 사용자가 직접 누른 다시 시도와 새로고침이다. 자동 호출은 `retryAt` 까지 기다린다.
    func synchronize(force: Bool = false) async {
        guard !busy else { return }
        if !force, let retryAt, retryAt > Date() { return }
        busy = true
        defer { busy = false }
        do {
            if hasOnlinePending { _ = try await replayOnlinePending() }
            // Restore committed requests before new-version checks: an old draw
            // receipt must remain recoverable after a coordinated upgrade.
            if hasPending {
                let pending = try JSONDecoder().decode(Request.self, from: Data(contentsOf: pendingURL))
                recoveredResult = try await send(pending)
            }
            if !ready {
                let version: RuleVersion = try await get("v1/rules")
                guard version.rules_version == ServerRulesBridge.version else {
                    throw Failure(message: "서버와 앱의 게임 규칙·시세 버전이 다릅니다. 같은 빌드로 업데이트하세요.")
                }
            }
            let status: PriceStatus = try await get("v1/prices")
            if let version = status.version, priceVersion != version {
                let data = try await api("v1/prices/snapshot")
                guard OpeningRules.digest(data) == version else { throw Failure(message: "시세 데이터 검증에 실패했습니다.") }
                try PriceSnapshotStore.shared.applyOnline(data, cacheURL: directory.appendingPathComponent("prices.json"))
                priceVersion = version
            }
            priceStatus = status
            let snapshot = try await fetchSnapshot()
            try accept(snapshot)
            ready = true
            authenticationExpired = false
            if snapshot.state.oripa == nil { _ = try await perform(.init(kind: "initialize")) }
            if collector.usedSinceInstall > reportedTokens {
                let total = collector.usedSinceInstall
                _ = try await perform(.init(kind: "report_tokens", collected_total: total))
                reportedTokens = total
            }
            error = nil
            lastFailure = nil
            failureStreak = 0
            retryAt = nil
            if summaryCheckedAt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true {
                await refreshNotificationSummary()
            }
        } catch {
            self.error = error.localizedDescription
            lastFailure = error
            ready = false
            if Self.isTransient(error) {
                failureStreak += 1
                // 2, 4, 8, 16, 32초, 그 뒤로는 60초마다.
                let delay = min(60, 2 << min(failureStreak - 1, 5))
                retryAt = Date().addingTimeInterval(TimeInterval(delay))
            } else {
                failureStreak = 0
                retryAt = nil
            }
            return
        }
    }

    /// 기다리면 나아질 수 있는 실패. 서버에 닿지 못했거나 서버가 5xx 를 냈다.
    static func isTransient(_ error: any Error) -> Bool {
        if error is ServerUnreachable { return true }
        if let status = (error as? any ServerTraceable)?.status { return status >= 500 }
        return false
    }

    /// 받은 교환 제안, 친구 신청, 안 읽은 알림 개수. 실패해도 동기화는 실패로 치지 않는다.
    func refreshNotificationSummary() async {
        guard !summaryUnsupported else { return }
        summaryCheckedAt = Date()
        do {
            let summary: NotificationSummary = try await get("v1/notifications/summary")
            if summary != notificationSummary { notificationSummary = summary }
        } catch let failure as Failure where failure.status == 404 {
            summaryUnsupported = true
        } catch {}
    }

    func execute(_ command: ServerRulesBridge.Command, expectedTokens: Int? = nil) async -> ServerRulesBridge.Result? {
        guard !hasOnlinePending else { error = "미확인 온라인 거래를 먼저 복구하세요."; return nil }
        guard !busy else { error = "다른 서버 요청을 처리하고 있습니다."; return nil }
        guard ready else { error = "서버 연결을 먼저 확인하세요. 로컬 자원은 변경하지 않았습니다."; return nil }
        guard !hasPending else { error = "응답을 확인하지 못한 요청이 있습니다. 먼저 재시도하세요."; return nil }
        busy = true
        defer { busy = false }
        do {
            return try await perform(command, expectedTokens: expectedTokens)
        } catch { self.error = error.localizedDescription; return nil }
    }

    private func perform(_ command: ServerRulesBridge.Command, expectedTokens: Int? = nil) async throws -> ServerRulesBridge.Result {
        var request = Request(request_id: UUID(), expected_revision: revision, command: command,
                              rules_version: ServerRulesBridge.version, price_version: priceVersion)
        if ["buy_packs", "sell_spares", "sell_bulk", "pull_oripa", "refresh_oripa"].contains(command.kind) {
            let data = try await api("v1/quotes", method: "POST", body: JSONEncoder().encode(request))
            let quote = try JSONDecoder().decode(Quote.self, from: data)
            guard quote.price_version == priceVersion, quote.revision == revision else {
                throw Failure(message: "가격이나 계정 상태가 바뀌었습니다. 동기화 후 금액을 다시 확인하세요.")
            }
            request.quoted_tokens = quote.tokens
            if let expectedTokens, expectedTokens != quote.tokens {
                throw Failure(message: "확인한 금액과 서버 견적이 다릅니다. 새로고침 후 변경된 금액을 다시 확인하세요.")
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(request).write(to: pendingURL, options: .atomic)
        hasPending = true
        return try await send(request)
    }

    func retryPending() async -> ServerRulesBridge.Result? {
        guard !busy, hasPending else { return nil }
        busy = true
        defer { busy = false }
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: pendingURL))
            return try await send(request)
        } catch { self.error = error.localizedDescription; return nil }
    }

    func dismissRecoveredResult() { recoveredResult = nil }

    func invalidateAuthentication() {
        cachedCredential = nil
        authenticationExpired = true
        ready = false
        error = ServerAuthentication.loginRequired
    }

    private func send(_ body: Request) async throws -> ServerRulesBridge.Result {
        var request = try await urlRequest("v1/commands")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 계정 상태 전체(오래 한 계정은 1.3MB, 대부분 개봉 기록) 대신 바뀐 부분만 받는다.
        request.setValue("1", forHTTPHeaderField: "X-PPB-State-Patch")
        request.httpBody = try JSONEncoder().encode(body)
        let exchange = try await ServerTransport.exchange(request)
        let data = exchange.data, status = exchange.status
        guard status != 0 else { throw Failure(message: "잘못된 서버 응답", requestID: exchange.requestID) }
        if status == 401 || status == 403 {
            invalidateAuthentication()
            // Keep the durable request: after re-login it must replay the same ID.
            throw Failure(message: ServerAuthentication.loginRequired, status: status, requestID: exchange.requestID)
        }
        if status == 409 || status == 422 {
            let text = String(decoding: data, as: UTF8.self)
            if !text.contains("idempotency_key_reused") {
                try clearPending()
                ready = false
            }
            throw Failure(message: "서버가 요청을 거절했습니다. 다른 기기에서 상태가 바뀌었거나 조건을 충족하지 않습니다. 새로고침 후 다시 시도하세요.",
                          status: status, requestID: exchange.requestID)
        }
        guard status == 200 else {
            throw Failure(message: "서버 응답 \(status). 요청 ID를 보존했습니다. 같은 요청으로 재시도할 수 있습니다.",
                          status: status, requestID: exchange.requestID)
        }
        let reply = try JSONDecoder().decode(Response.self, from: data)
        try accept(try await resolvedSnapshot(reply.snapshot, data: data))
        try clearPending()
        error = nil
        return reply.result
    }

    /// 변경분을 적용한 횟수. 통합 검사가 변경분 경로를 실제로 탔는지 확인한다.
    @ObservationIgnored private(set) var appliedStatePatches = 0

    /// 명령 응답이 바뀐 부분만 담고 있으면 가진 상태에 적용한다. 가진 상태가 서버가 말한 이전
    /// 상태와 정확히 같을 때(지문 비교)만 적용하고, 아니면 전체 상태를 다시 받는다. 서버는 버전을
    /// 올리지 않고 상태를 정리하는 경우가 있어 버전 번호만으로는 같은 상태라고 볼 수 없다.
    private func resolvedSnapshot(_ full: Snapshot?, data: Data) async throws -> Snapshot {
        if let full { return full }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patch = object["snapshot_patch"] as? [String: Any] else {
            throw Failure(message: "서버 응답에 계정 상태가 없어요.")
        }
        if let base = lastSnapshot, base.revision == patch["base_revision"] as? Int,
           let digest = base.state_digest, digest == patch["base_digest"] as? String {
            do {
                let patched = try Self.applying(patch, to: base)
                appliedStatePatches += 1
                return patched
            } catch {
                AppLog.write("[online] state patch could not be applied: \(String(describing: error).prefix(300)); fetching full state")
            }
        } else {
            AppLog.write("[online] state patch base differs from local state; fetching full state")
        }
        return try await fetchSnapshot()
    }

    /// 서버 `state_patch` 의 적용. 순서는 값 교체, 사전 항목 교체, 키 삭제, 개봉 기록 앞쪽 버리고 뒤에 붙이기.
    static func applying(_ patch: [String: Any], to base: Snapshot) throws -> Snapshot {
        guard var state = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base.state)) as? [String: Any],
              let accountID = patch["account_id"] as? String,
              let revision = patch["revision"] as? Int,
              let balance = patch["balance"] as? Int else {
            throw Failure(message: "계정 상태 변경분을 읽지 못했어요.")
        }
        for (key, value) in patch["set"] as? [String: Any] ?? [:] { state[key] = value }
        for (key, change) in patch["merge"] as? [String: [String: Any]] ?? [:] {
            var merged = state[key] as? [String: Any] ?? [:]
            for (entry, value) in change["set"] as? [String: Any] ?? [:] { merged[entry] = value }
            for entry in change["remove"] as? [String] ?? [] { merged.removeValue(forKey: entry) }
            state[key] = merged
        }
        for key in patch["remove"] as? [String] ?? [] { state.removeValue(forKey: key) }
        if let history = patch["history"] as? [String: Any] {
            var records = state["openingHistory"] as? [Any] ?? []
            records.removeFirst(min(max(0, history["drop"] as? Int ?? 0), records.count))
            records.append(contentsOf: history["append"] as? [Any] ?? [])
            state["openingHistory"] = records
        }
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: state))
        return Snapshot(account_id: accountID, revision: revision, balance: balance, state: decoded,
                        reserved: patch["reserved"] as? [String: Int],
                        state_digest: patch["state_digest"] as? String)
    }

    private func clearPending() throws {
        try FileManager.default.removeItem(at: pendingURL)
        hasPending = false
    }

    private func accept(_ snapshot: Snapshot) throws {
        guard UUID(uuidString: snapshot.account_id) == configuration.accountID,
              snapshot.revision >= revision else { throw Failure(message: "계정 또는 버전이 맞지 않는 응답입니다.") }
        if acceptedSnapshot && snapshot.revision == revision { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try GamePersistence(url: cacheURL).commit(snapshot.state)
        revision = snapshot.revision
        acceptedSnapshot = true
        lastSnapshot = snapshot
        reservedPrintings = snapshot.reserved ?? [:]
        onSnapshot?(snapshot.state)
    }

    private func fetchSnapshot() async throws -> Snapshot {
        var request = try await urlRequest("v1/state")
        if acceptedSnapshot { request.setValue("\"\(revision)\"", forHTTPHeaderField: "If-None-Match") }
        let exchange = try await ServerTransport.exchange(request)
        let status = exchange.status
        if status == 401 || status == 403 {
            invalidateAuthentication()
            throw Failure(message: ServerAuthentication.loginRequired, status: status, requestID: exchange.requestID)
        }
        if status == 304, let lastSnapshot { return lastSnapshot }
        guard status == 200 else {
            throw Failure(message: "서버 상태를 가져오지 못했습니다. (HTTP \(status))", status: status, requestID: exchange.requestID)
        }
        return try JSONDecoder().decode(Snapshot.self, from: exchange.data)
    }

    /// 계정 창에서 같은 계정으로 다시 로그인했을 때 새 로그인 정보를 읽게 한다.
    func forgetCredential() { cachedCredential = nil }

    /// 키체인은 세션마다 한 번, 메인 스레드 밖에서 읽는다. 앱 서명이 바뀐 뒤(업데이트 등) 첫 읽기는
    /// macOS 의 접근 허용 창에 답할 때까지 멈추는데, 메인 스레드에서 읽으면 그동안 메뉴바 아이콘조차
    /// 그리지 못해 앱이 실행되지 않은 것처럼 보였다(v0.12.0 업데이트 직후 실제로 겪음).
    private func accessToken() async throws -> String? {
        if let tokenProvider { return try tokenProvider() }
        let now = Int(Date().timeIntervalSince1970)
        if let cached = cachedCredential, cached.expires_at > now { return cached.access_token }
        let configuration = self.configuration
        let credential = try await Task.detached(priority: .userInitiated) {
            try ServerCredentialStore.load(configuration)
        }.value
        cachedCredential = credential
        guard let credential, credential.expires_at > now else { return nil }
        return credential.access_token
    }

    private func urlRequest(_ path: String) async throws -> URLRequest {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path),
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 90
        let token = try await accessToken()
        guard let token, !token.isEmpty else {
            invalidateAuthentication()
            throw Failure(message: ServerAuthentication.loginRequired)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.accountID.uuidString.lowercased(), forHTTPHeaderField: "X-PPB-Account-ID")
        request.setValue(configuration.deviceID.uuidString.lowercased(), forHTTPHeaderField: "X-PPB-Device-ID")
        if let key = ProcessInfo.processInfo.environment["PPB_GATEWAY_KEY"], !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-PPB-Gateway-Key")
        }
        return request
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let exchange = try await ServerTransport.exchange(await urlRequest(path))
        let status = exchange.status
        if status == 401 || status == 403 {
            invalidateAuthentication()
            throw Failure(message: ServerAuthentication.loginRequired, status: status, requestID: exchange.requestID)
        }
        guard status == 200 else {
            throw Failure(message: Self.describe(status: status, data: exchange.data), status: status, requestID: exchange.requestID)
        }
        return try JSONDecoder().decode(T.self, from: exchange.data)
    }

    func api(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        var request = try await urlRequest(parts[0])
        if parts.count > 1, var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) {
            components.percentEncodedQuery = parts[1]
            request.url = components.url
        }
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let exchange = try await ServerTransport.exchange(request)
        let status = exchange.status
        if status == 401 {
            invalidateAuthentication()
            throw Failure(message: ServerAuthentication.loginRequired, status: status, requestID: exchange.requestID)
        }
        guard (200..<300).contains(status) else {
            throw Failure(message: Self.describe(status: status, data: exchange.data), status: status, requestID: exchange.requestID)
        }
        return exchange.data
    }

    /// 실패 응답을 사람이 읽을 문장으로. 4xx 는 서버가 준 이유 코드를 그대로 붙인다 — 복구 판단
    /// (`idempotency_key_reused`)이 이 문장을 본다.
    static func describe(status: Int, data: Data) -> String {
        let detail = ServerTransport.detail(data) ?? "HTTP \(status)"
        if status >= 500 {
            return "서버에서 오류가 났어요 (HTTP \(status), \(detail)). 잠시 뒤 다시 시도해 주세요."
        }
        return "요청을 완료하지 못했습니다: \(detail). 새로고침 후 조건을 다시 확인하세요."
    }

    func onlineMutation(path: String, body: Data) async throws -> Data {
        guard ready, !busy, !hasPending, !hasOnlinePending else {
            throw Failure(message: "다른 요청 또는 미확인 거래를 먼저 복구하세요.")
        }
        busy = true
        defer { busy = false }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(OnlinePending(path: path, body: body)).write(to: onlinePendingURL, options: .atomic)
        hasOnlinePending = true
        return try await replayOnlinePending()
    }

    func createOpeningJob(setID: String, count: Int) async throws -> OpeningJob {
        let body: [String: Any] = ["request_id": UUID().uuidString, "expected_revision": revision,
            "set_id": setID, "count": count, "rules_version": ServerRulesBridge.version]
        let data = try await onlineMutation(path: "v1/opening-jobs", body: JSONSerialization.data(withJSONObject: body))
        return try JSONDecoder().decode(OpeningJobReply.self, from: data).result.job
    }

    func advanceOpeningJob(_ job: OpeningJob, cancel: Bool = false) async throws -> OpeningJobResult {
        let body: [String: Any] = ["request_id": UUID().uuidString, "expected_revision": revision, "target_version": job.version]
        let path = "v1/opening-jobs/\(job.id)/\(cancel ? "cancel" : "step")"
        let data = try await onlineMutation(path: path, body: JSONSerialization.data(withJSONObject: body))
        return try JSONDecoder().decode(OpeningJobReply.self, from: data).result
    }

    private func replayOnlinePending() async throws -> Data {
        let pending = try JSONDecoder().decode(OnlinePending.self, from: Data(contentsOf: onlinePendingURL))
        do {
            let data = try await api(pending.path, method: "POST", body: pending.body)
            struct Reply: Decodable { let snapshot: Snapshot }
            try accept(JSONDecoder().decode(Reply.self, from: data).snapshot)
            try FileManager.default.removeItem(at: onlinePendingURL)
            hasOnlinePending = false
            return data
        } catch let failure as Failure {
            if let status = failure.status, [400, 403, 404, 409, 422].contains(status),
               !failure.message.contains("idempotency_key_reused") {
                try FileManager.default.removeItem(at: onlinePendingURL)
                hasOnlinePending = false
                ready = false
            }
            throw failure
        }
    }
}
