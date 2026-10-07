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
        let snapshot: Snapshot
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

    func synchronize() async {
        guard !busy else { return }
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
        } catch {
            self.error = error.localizedDescription
            lastFailure = error
            ready = false
            return
        }
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
        try accept(reply.snapshot)
        try clearPending()
        error = nil
        return reply.result
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
