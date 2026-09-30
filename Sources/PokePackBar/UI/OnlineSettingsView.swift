import SwiftUI

/// Connection changes take effect on restart. Authentication never replaces
/// a live wallet or discards an unresolved resource command.
@MainActor
struct OnlineSettingsView: View {
    let wallet: WalletStore
    private let auditing: Bool
    @State private var enabled = UserDefaults.standard.bool(forKey: "ppb.server.enabled")
    @State private var address = UserDefaults.standard.string(forKey: "ppb.server.url") ?? "http://127.0.0.1:8000"
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var linkCode = ""
    @State private var registering = false
    @State private var linking = false
    @State private var busy = false
    @State private var credential: ServerCredential?
    @State private var message: String?
    @State private var section = "연결"
    @State private var devices: [AccountDevice] = []
    @State private var jobs: [AccountJob] = []
    @State private var recoveryCode = ""
    @State private var recoveryInput = ""
    @State private var recoveryActive = false
    @State private var deviceNames: [String: String] = [:]
    @State private var confirmingRevoke: AccountDevice?
    @State private var confirmingRecovery = false
    @State private var statusLoaded = false
    @State private var tokenPolicy = AccountTokenPolicy(collector_device_id: nil, version: 0)
    @State private var latencies: [String: AccountLatency] = [:]
    @State private var confirmingTokenPolicy: Bool?
    private var actionsDisabled: Bool { busy || wallet.remote?.busy == true || wallet.isOpeningPacks }
    private var unconfirmed: Bool { wallet.remote.map { $0.hasPending || $0.hasOnlinePending } ?? false }

    init(wallet: WalletStore, auditSection: String? = nil, signedIn: Bool = false) {
        self.wallet = wallet
        auditing = auditSection != nil
        if let auditSection {
            _section = State(initialValue: auditSection)
            _enabled = State(initialValue: false)
            _address = State(initialValue: "http://127.0.0.1:8000")
            _statusLoaded = State(initialValue: true)
            if signedIn {
                _credential = State(initialValue: ServerCredential(access_token: "layout-fixture-not-a-token",
                    account_id: UUID(), device_id: UUID(), email: "layout@example.invalid", expires_at: 0))
            }
            _devices = State(initialValue: [AccountDevice(device_id: UUID().uuidString, name: "집에서 사용하는 MacBook Pro",
                last_login: 1_790_738_400, current: true), AccountDevice(device_id: UUID().uuidString,
                name: "여행용 Mac", last_login: nil, current: false)])
            _jobs = State(initialValue: [AccountJob(name: "backup", state: "ok", last_success: 1_790_738_400, next_run: nil, error: nil),
                AccountJob(name: "prices", state: "failed", last_success: nil, next_run: nil, error: "시세 갱신 실패: 마지막 정상 가격을 유지하고 1시간 후 재시도합니다."),
                AccountJob(name: "expiry", state: "running", last_success: nil, next_run: nil, error: nil)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("계정 및 서버").font(.title2.bold())
                    Text(credential?.email ?? "로그인하여 기기 간 컬렉션을 연결하세요")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            Picker("계정 관리 분류", selection: $section) {
                ForEach(["연결", "보안", "기기", "서버 상태"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).disabled(busy)
                .onChange(of: section) { clearSecrets(); if section != "연결" && !auditing { refreshAccount() } }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == "연결" { connection }
                    else if section == "보안" { security }
                    else if section == "기기" { deviceList }
                    else { serverStatus }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }.disabled(busy)
            if let message {
                Divider()
                Text(message).font(.callout).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { if !auditing { loadSavedLogin() } }
        .onDisappear { clearSecrets(); devices = []; jobs = []; credential = nil }
        .alert("이 기기의 연결을 해제할까요?", isPresented: Binding(
            get: { confirmingRevoke != nil }, set: { if !$0 { confirmingRevoke = nil } })) {
            Button("취소", role: .cancel) { confirmingRevoke = nil }
            Button("연결 해제", role: .destructive) {
                if let device = confirmingRevoke { revoke(device) }; confirmingRevoke = nil
            }
        } message: { Text("해당 기기는 다시 로그인해야 합니다. 카드와 잔액은 삭제되지 않습니다.") }
        .alert("새 복구 코드를 발급할까요?", isPresented: $confirmingRecovery) {
            Button("취소", role: .cancel) { }
            Button("발급") { issueRecovery() }
        } message: { Text("기존 코드는 즉시 무효화됩니다. 새 코드는 한 번만 표시되므로 비밀번호 관리자에 보관하세요.") }
        .alert("토큰 적립 방식을 바꿀까요?", isPresented: Binding(
            get: { confirmingTokenPolicy != nil }, set: { if !$0 { confirmingTokenPolicy = nil } })) {
            Button("취소", role: .cancel) { confirmingTokenPolicy = nil }
            Button("변경") { if let single = confirmingTokenPolicy { updateTokenPolicy(single: single) }; confirmingTokenPolicy = nil }
        } message: {
            Text("변경 후 각 기기의 첫 사용량 보고는 기준값만 저장하고 지급하지 않습니다. 이후 증가분부터 새 정책으로 적립합니다. 기존 잔액은 변하지 않습니다.")
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("사용 모드") {
                VStack(alignment: .leading, spacing: 10) {
            Toggle("서버에서 자원 관리 (재시작 후 적용)", isOn: $enabled)
                        .disabled(actionsDisabled || unconfirmed)
                    Text("로컬 세이브와 온라인 계정은 분리됩니다. 모드를 바꿔도 자동 이전하거나 합치지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("모드 설정 저장") { saveConfiguration() }.disabled(actionsDisabled)
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup("서버 주소 · 고급 연결") {
            TextField("서버 URL", text: $address).textFieldStyle(.roundedBorder)
                .disabled(busy)
                .onChange(of: address) { credential = nil; devices = []; jobs = []; clearSecrets() }
                Text("같은 서버 주소를 사용해야 다른 기기와 연결됩니다. 원격 주소는 HTTPS가 필요합니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if credential == nil {
                loginForm
            } else {
                GroupBox("연결된 계정") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(credential?.email ?? "").textSelection(.enabled)
                        Text("기기별 연결 해제와 비밀번호 변경은 위 탭에서 관리합니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("온라인 컬렉션 열기") { OnlineWindow.shared.show(wallet: wallet) }
                        Button("로그인 갱신 / 다른 계정") { credential = nil; devices = []; jobs = []; clearSecrets() }
                            .disabled(actionsDisabled)
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let remote = wallet.remote {
                Text("현재 실행: \(remote.ready ? "온라인 연결됨" : "온라인 연결 확인 필요") · 상태 버전 \(remote.revision)")
                    .font(.caption).foregroundStyle(.secondary)
                Button(unconfirmed ? "미확인 요청 복구 및 동기화" : "지금 동기화") {
                    Task { await remote.synchronize() }
                }.disabled(remote.busy)
                if let error = remote.error { Text(error).font(.caption).foregroundStyle(.orange) }
            } else { Text("현재 실행은 로컬 모드입니다.").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var loginForm: some View {
        GroupBox(registering ? "새 계정 가입" : "이메일 로그인") {
            VStack(alignment: .leading, spacing: 10) {
            TextField("이메일", text: $email).textFieldStyle(.roundedBorder)
                .textContentType(.username).disabled(busy)
            SecureField("비밀번호", text: $password).textFieldStyle(.roundedBorder)
                .textContentType(.password).disabled(busy)
            Toggle("새 계정 가입", isOn: $registering).disabled(busy)
            if registering {
                SecureField("비밀번호 확인 (\(ServerPasswordPolicy.lengthDescription))", text: $confirmation).textFieldStyle(.roundedBorder)
                DisclosureGroup("기존 UUID 계정 연결 (선택)") {
                    Toggle("일회용 연결 코드 사용", isOn: $linking).disabled(busy)
                    if linking {
                    SecureField("서버에서 발급한 일회용 연결 코드", text: $linkCode).textFieldStyle(.roundedBorder)
                    Text("서버의 issue-link-code 명령으로 발급합니다. UUID만으로는 연결할 수 없으며 기존 카드·잔액은 그대로 유지됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Button(registering ? "가입 및 연결" : "로그인") { authenticate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(actionsDisabled || email.isEmpty || password.isEmpty)
            }
            Text("같은 서버에서 같은 이메일로 로그인하면 다른 기기에서도 카드와 잔액을 공유합니다. 이메일 수신 인증은 하지 않으며, 기존 로컬 세이브는 자동 업로드하지 않습니다.")
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(6)
        }
    }

    private var security: some View {
        VStack(alignment: .leading, spacing: 16) {
            if credential != nil {
                GroupBox("로그인 세션") {
                HStack {
                    Button("이 기기 로그아웃") { logout(all: false) }
                    Button("모든 기기 로그아웃") { logout(all: true) }
                }.disabled(actionsDisabled || unconfirmed)
                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                SecureField("현재 비밀번호 (변경·복구 코드 발급 시 확인)", text: $password)
                    .textFieldStyle(.roundedBorder).disabled(busy)
                DisclosureGroup("비밀번호 변경") {
                    Text("변경하면 모든 기기에서 로그아웃되고 기존 복구 코드도 무효화됩니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("새 비밀번호 (\(ServerPasswordPolicy.lengthDescription))", text: $newPassword).textFieldStyle(.roundedBorder)
                    SecureField("새 비밀번호 확인", text: $newPasswordConfirmation).textFieldStyle(.roundedBorder)
                    Button("비밀번호 변경 및 전체 로그아웃") { changePassword() }
                        .disabled(actionsDisabled || password.isEmpty || unconfirmed)
                }
                GroupBox("일회용 계정 복구 코드") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recoveryActive ? "사용 가능한 복구 코드가 있습니다." : "복구 코드를 발급해 비밀번호 분실에 대비하세요.")
                        Text("이 코드를 아는 사람은 비밀번호를 바꿀 수 있습니다. 앱은 원문을 저장하지 않습니다. 화면을 닫으면 다시 볼 수 없습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(recoveryActive ? "복구 코드 재발급…" : "복구 코드 발급…") { confirmingRecovery = true }
                            .disabled(actionsDisabled || password.isEmpty || unconfirmed)
                        if !recoveryCode.isEmpty {
                            Text(recoveryCode).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            Button("안전한 곳에 보관했습니다 · 숨기기") { recoveryCode = "" }
                        }
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("비밀번호를 잊었나요?").font(.headline)
                Text("미리 저장한 일회용 복구 코드로 비밀번호를 재설정합니다. 코드가 없으면 서버 운영자의 재설정이 필요합니다.")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("이메일", text: $email).textFieldStyle(.roundedBorder)
                SecureField("저장해 둔 복구 코드", text: $recoveryInput).textFieldStyle(.roundedBorder)
                SecureField("새 비밀번호 (8~128자)", text: $newPassword).textFieldStyle(.roundedBorder)
                SecureField("새 비밀번호 확인", text: $newPasswordConfirmation).textFieldStyle(.roundedBorder)
                Button("비밀번호 재설정 및 전체 로그아웃") { recoverAccount() }
                    .disabled(actionsDisabled || recoveryInput.isEmpty)
            }
        }
    }

    private func saveConfiguration() {
        guard !enabled || credential != nil else {
            message = "온라인 모드를 켜려면 먼저 로그인하세요."
            return
        }
        guard !unconfirmed, wallet.remote?.busy != true else {
            message = "진행 중이거나 결과가 미확인인 요청을 먼저 동기화하세요."
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "ppb.server.enabled")
        message = "저장했습니다. 앱을 완전히 종료하고 다시 실행하면 적용됩니다."
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("현재 로그인한 기기").font(.headline)
            Text("최근 로그인 시각이며 실시간 접속 상태는 아닙니다. 연결 해제 후에도 해당 기기에서 비밀번호로 다시 로그인할 수 있습니다.")
                .font(.caption).foregroundStyle(.secondary)
            Button("새로고침") { refreshAccount() }.disabled(busy || credential == nil)
            if credential != nil {
                DisclosureGroup("토큰 적립 담당") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tokenPolicy.collector_device_id == nil ? "현재: 모든 기기의 독립 사용량 합산" : "현재: 지정한 한 기기만 적립")
                        Text("같은 사용량을 여러 Mac에서 읽는다면 한 대만 지정하세요. 이는 적립 경로 제한이며 보고한 사용량의 진위 검증은 아닙니다.")
                            .font(.caption).foregroundStyle(.secondary)
                        SecureField("정책 변경 확인용 현재 비밀번호", text: $password).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("이 Mac만 적립…") { confirmingTokenPolicy = true }
                            Button("모든 기기 합산…") { confirmingTokenPolicy = false }
                        }.disabled(actionsDisabled || unconfirmed || password.isEmpty || !statusLoaded)
                    }.padding(.top, 8)
                }
            }
            if credential == nil { Text("연결 탭에서 먼저 로그인하세요.") }
            else if statusLoaded && devices.isEmpty { Text("활성 기기가 없습니다. 다시 로그인하세요.") }
            ForEach(devices) { device in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("기기 이름", text: Binding(get: { deviceNames[device.id] ?? device.name },
                                set: { deviceNames[device.id] = $0 })).textFieldStyle(.roundedBorder)
                            if device.current { Text("이 기기").font(.caption).foregroundStyle(.secondary) }
                        }
                        Text("최근 로그인: \(dateText(device.last_login))").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("이름 저장") { rename(device) }
                            Spacer()
                            Button("연결 해제…", role: .destructive) { confirmingRevoke = device }
                        }.disabled(actionsDisabled || unconfirmed)
                    }.padding(6)
                }
            }
        }
    }

    private var serverStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("자동 작업 상태").font(.headline)
                Spacer()
                Button("새로고침") { refreshAccount() }.disabled(busy || credential == nil)
            }
            if credential == nil { Text("서버 상태를 보려면 먼저 로그인하세요.") }
            ForEach(jobs) { job in
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(job.title).font(.headline)
                            Spacer()
                            Label(job.label, systemImage: job.needsAttention ? "exclamationmark.triangle" : "clock")
                                .foregroundStyle(job.needsAttention ? Color.orange : Color.secondary)
                        }
                        Text("마지막 성공: \(dateText(job.last_success))").font(.caption)
                        Text("다음 실행: \(dateText(job.next_run))").font(.caption).foregroundStyle(.secondary)
                        if let error = job.error { Text(error).font(.callout).foregroundStyle(.orange) }
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text("서버가 꺼져 있으면 자동 작업도 멈춥니다. 백업은 서버 디스크에 보관하므로 디스크 고장 대비용 외부 백업은 별도입니다.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("진단 정보") {
                Text("토큰 적립: 클라이언트 보고 신뢰 · 실제 사용량 검증 아님")
                ForEach(latencies.keys.sorted(), id: \.self) { key in
                    if let metric = latencies[key] {
                        Text("\(key == "rules" ? "규칙 실행" : "DB 쓰기 대기"): P50 \(metric.p50_ms, specifier: "%.1f")ms / P95 \(metric.p95_ms, specifier: "%.1f")ms (\(metric.samples)회)")
                    }
                }
                Text("시간은 응답한 서버 프로세스의 최근 200회 기준입니다. 서버 재시작 시 초기화됩니다.")
                if let credential { Text("계정 ID: \(credential.account_id.uuidString)").textSelection(.enabled) }
                Text(address).textSelection(.enabled)
            }.font(.caption)
        }
    }

    private func dateText(_ value: Int?) -> String {
        guard let value, value > 0 else { return "기록 없음" }
        return Date(timeIntervalSince1970: Double(value)).formatted(date: .abbreviated, time: .shortened)
    }

    private func clearSecrets() {
        password = ""; confirmation = ""; newPassword = ""; newPasswordConfirmation = ""
        linkCode = ""; recoveryCode = ""; recoveryInput = ""
    }

    private func refreshAccount() {
        guard !busy, let credential else { return }
        busy = true; statusLoaded = false
        Task {
            defer { busy = false }
            do {
                let url = try validatedURL()
                if section == "기기" {
                    let data = try await ServerAuthentication.request(url: url, path: "auth/devices", credential: credential, method: "GET")
                    devices = try JSONDecoder().decode(AccountDeviceList.self, from: data).items
                    deviceNames = [:]
                    let policyData = try await ServerAuthentication.request(url: url, path: "auth/token-policy", credential: credential, method: "GET")
                    tokenPolicy = try JSONDecoder().decode(AccountTokenPolicy.self, from: policyData)
                } else if section == "서버 상태" {
                    let data = try await ServerAuthentication.request(url: url, path: "v1/server/status", credential: credential, method: "GET")
                    let status = try JSONDecoder().decode(AccountJobList.self, from: data)
                    jobs = status.jobs; latencies = status.latency_worker_recent ?? [:]
                } else if section == "보안" {
                    let data = try await ServerAuthentication.request(url: url, path: "auth/recovery", credential: credential, method: "GET")
                    recoveryActive = try JSONDecoder().decode(AccountRecoveryStatus.self, from: data).active
                }
                statusLoaded = true; message = nil
            } catch {
                devices = []; jobs = []; message = error.localizedDescription
                if error.localizedDescription == ServerAuthentication.loginRequired { self.credential = nil; clearSecrets() }
            }
        }
    }

    private func rename(_ device: AccountDevice) {
        let name = (deviceNames[device.id] ?? device.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.unicodeScalars.count <= 80 else { message = "기기 이름은 1~80자로 입력하세요."; return }
        accountAction(path: "auth/devices/\(device.id)/rename", body: ["name": name])
    }

    private func revoke(_ device: AccountDevice) {
        if device.current { logout(all: false); return }
        accountAction(path: "auth/devices/\(device.id)/revoke")
    }

    private func accountAction(path: String, body: [String: String] = [:]) {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true
        Task {
            do {
                _ = try await ServerAuthentication.request(url: validatedURL(), path: path, body: body, credential: credential)
                busy = false; refreshAccount()
            } catch { busy = false; message = error.localizedDescription }
        }
    }

    private func issueRecovery() {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true; recoveryCode = ""
        Task {
            defer { busy = false; password = "" }
            do {
                let data = try await ServerAuthentication.request(url: validatedURL(), path: "auth/recovery", body: ["password": password], credential: credential)
                recoveryCode = try JSONDecoder().decode(AccountIssuedRecovery.self, from: data).code
                recoveryActive = true; message = "새 복구 코드를 안전한 곳에 보관하세요. 기존 코드는 무효화됐습니다."
            } catch { message = "\(error.localizedDescription) 응답을 받지 못했다면 다시 발급하세요. 이전 코드는 무효화될 수 있습니다." }
        }
    }

    private func updateTokenPolicy(single: Bool) {
        guard !actionsDisabled, !unconfirmed, let credential else { return }
        busy = true
        Task {
            defer { busy = false; password = "" }
            do {
                let body: [String: Any] = ["password": password, "expected_version": tokenPolicy.version,
                    "collector_device_id": single ? credential.device_id.uuidString as Any : NSNull()]
                let data = try await ServerAuthentication.request(url: validatedURL(), path: "auth/token-policy", body: body, credential: credential)
                tokenPolicy = try JSONDecoder().decode(AccountTokenPolicy.self, from: data)
                message = "적립 정책을 변경했습니다. 첫 보고를 기준으로 이후 증가분부터 적립합니다."
            } catch { message = "\(error.localizedDescription) 새로고침으로 현재 정책을 확인하세요." }
        }
    }

    private func recoverAccount() {
        // Password recovery must remain available when an expired login has a pending draw.
        // The pending resource request is preserved and replayed after same-account login.
        guard !actionsDisabled else { return }
        guard ServerPasswordPolicy.accepts(newPassword), newPassword == newPasswordConfirmation else {
            message = "8~128자의 새 비밀번호를 두 칸에 동일하게 입력하세요."; return
        }
        busy = true
        Task {
            defer { busy = false; clearSecrets() }
            do {
                _ = try await ServerAuthentication.request(url: validatedURL(), path: "auth/recover",
                    body: ["email": email, "code": recoveryInput, "new_password": newPassword])
                section = "연결"; message = "재설정했습니다. 새 비밀번호로 로그인하고 복구 코드를 다시 발급하세요."
            } catch { message = "\(error.localizedDescription) 응답이 유실됐다면 새 비밀번호로 로그인을 먼저 시도하세요." }
        }
    }

    private func validatedURL() throws -> URL {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              RemoteGameConfiguration.validURL(url) else {
            throw ServerLoginFailure(message: "서버 URL을 확인하세요. 원격 서버는 HTTPS가 필요합니다.")
        }
        return url
    }

    private func configuration(for credential: ServerCredential) throws -> RemoteGameConfiguration {
        .init(baseURL: try validatedURL(), accountID: credential.account_id, deviceID: credential.device_id)
    }

    private func loadSavedLogin() {
        guard let account = UUID(uuidString: UserDefaults.standard.string(forKey: "ppb.server.account") ?? ""),
              let url = try? validatedURL() else { return }
        let config = RemoteGameConfiguration(baseURL: url, accountID: account, deviceID: ServerAuthentication.deviceID())
        if let saved = try? ServerCredentialStore.load(config) { credential = saved; email = saved.email }
    }

    private func authenticate() {
        guard !actionsDisabled else { return }
        if registering && (!ServerPasswordPolicy.accepts(password) || password != confirmation) {
            message = "\(ServerPasswordPolicy.lengthDescription)의 비밀번호를 두 칸에 동일하게 입력하세요."
            return
        }
        if registering && linking && linkCode.isEmpty { message = "연결 코드가 필요합니다."; return }
        busy = true
        Task {
            defer { busy = false; password = ""; confirmation = ""; linkCode = "" }
            do {
                let url = try validatedURL()
                let result = try await ServerAuthentication.login(url: url, email: email, password: password,
                    register: registering, linkCode: registering && linking ? linkCode : "",
                    deviceID: ServerAuthentication.deviceID())
                let config = RemoteGameConfiguration(baseURL: url, accountID: result.account_id, deviceID: result.device_id)
                if let remote = wallet.remote, unconfirmed,
                   remote.configuration.storageKey != config.storageKey {
                    // A new session was created but must not replace the account
                    // that owns the durable pending request.
                    _ = try? await ServerAuthentication.request(url: url, path: "auth/logout", credential: result)
                    throw ServerLoginFailure(message: "미확인 요청이 있는 기존 계정으로 먼저 로그인해 복구하세요.")
                }
                try ServerCredentialStore.save(result, configuration: config)
                credential = result
                let defaults = UserDefaults.standard
                defaults.set(url.absoluteString, forKey: "ppb.server.url")
                defaults.set(result.account_id.uuidString.lowercased(), forKey: "ppb.server.account")
                defaults.set(true, forKey: "ppb.server.enabled")
                enabled = true
                if let remote = wallet.remote, remote.configuration.storageKey == config.storageKey {
                    await remote.synchronize()
                    message = "로그인했습니다. 기존 계정 상태를 동기화했습니다."
                } else { message = "로그인했습니다. 앱을 완전히 종료하고 다시 실행하면 이 계정에 연결됩니다." }
            } catch { message = error.localizedDescription }
        }
    }

    private func logout(all: Bool) {
        guard let credential, !actionsDisabled, !unconfirmed else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await ServerAuthentication.logout(configuration: configuration(for: credential), credential: credential, all: all)
                finishLogout()
            } catch { message = error.localizedDescription }
        }
    }

    private func changePassword() {
        guard let credential, !actionsDisabled, !unconfirmed else { return }
        guard ServerPasswordPolicy.accepts(newPassword), newPassword == newPasswordConfirmation else {
            message = "\(ServerPasswordPolicy.lengthDescription)의 새 비밀번호를 두 칸에 동일하게 입력하세요."; return
        }
        busy = true
        Task {
            defer { busy = false; password = ""; newPassword = ""; newPasswordConfirmation = "" }
            do {
                try await ServerAuthentication.changePassword(configuration: configuration(for: credential), credential: credential,
                    current: password, new: newPassword)
                finishLogout()
                message = "비밀번호를 변경하고 모든 기기에서 로그아웃했습니다. 새 비밀번호로 다시 로그인하세요."
            } catch { message = error.localizedDescription }
        }
    }

    private func finishLogout() {
        credential = nil
        clearSecrets(); devices = []; jobs = []; recoveryActive = false
        wallet.remote?.invalidateAuthentication()
        // Keep online mode selected: logout must not silently switch wallets.
        message = "로그아웃했습니다. 온라인 자원은 유지되며 다시 로그인하기 전까지 변경할 수 없습니다."
    }
}

struct AccountDevice: Decodable, Identifiable {
    let device_id: String
    let name: String
    let last_login: Int?
    let current: Bool
    var id: String { device_id }
}
struct AccountDeviceList: Decodable { let items: [AccountDevice] }
struct AccountRecoveryStatus: Decodable { let active: Bool }
struct AccountIssuedRecovery: Decodable { let code: String }
struct AccountJobList: Decodable { let jobs: [AccountJob]; let latency_worker_recent: [String: AccountLatency]? }
struct AccountLatency: Decodable { let samples: Int; let p50_ms: Double; let p95_ms: Double }
struct AccountTokenPolicy: Decodable { let collector_device_id: String?; let version: Int }
struct AccountJob: Decodable, Identifiable {
    let name: String
    let state: String
    let last_success: Int?
    let next_run: Int?
    let error: String?
    var id: String { name }
    var title: String { ["backup": "자동 백업 · 복원 검사", "prices": "시세 갱신", "expiry": "거래 만료 처리"][name] ?? name }
    var label: String { ["ok": "정상", "failed": "실패", "stale": "지연", "running": "진행 중", "waiting": "첫 실행 대기", "disabled": "비활성"][state] ?? state }
    var needsAttention: Bool { ["failed", "stale", "disabled"].contains(state) }
}
