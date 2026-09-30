import Foundation
import LocalAuthentication
import Security

enum ServerPasswordPolicy {
    static let lengthRange = 8...128
    static let lengthDescription = "8~128자"

    static func accepts(_ password: String) -> Bool {
        // Match Python's Unicode code-point count without altering the password.
        lengthRange.contains(password.unicodeScalars.count)
    }
}

struct ServerLoginFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Login passwords are transient form input. Only the server's revocable
/// session is persisted, in this app's own non-synchronizing Keychain item.
struct ServerCredential: Codable, Sendable {
    let access_token: String
    let account_id: UUID
    let device_id: UUID
    let email: String
    let expires_at: Int
}

enum ServerCredentialStore {
    private static let service = "dev.local.pokepackbar.server-session"

    private static func query(_ configuration: RemoteGameConfiguration) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: configuration.storageKey,
         kSecAttrSynchronizable as String: false]
    }

    static func load(_ configuration: RemoteGameConfiguration) throws -> ServerCredential? {
        var fields = query(configuration)
        fields[kSecReturnData as String] = true
        fields[kSecMatchLimit as String] = kSecMatchLimitOne
        // Background synchronization must never trigger a Keychain prompt.
        let context = LAContext()
        context.interactionNotAllowed = true
        fields[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(fields as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw ServerLoginFailure(message: "로그인 정보를 읽을 수 없습니다. 설정에서 다시 로그인하세요.")
        }
        let credential = try JSONDecoder().decode(ServerCredential.self, from: data)
        guard credential.account_id == configuration.accountID,
              credential.device_id == configuration.deviceID else {
            throw ServerLoginFailure(message: "현재 기기와 로그인 정보가 맞지 않습니다. 다시 로그인하세요.")
        }
        return credential
    }

    static func save(_ credential: ServerCredential, configuration: RemoteGameConfiguration) throws {
        let data = try JSONEncoder().encode(credential)
        let fields = query(configuration)
        let status = SecItemUpdate(fields as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw ServerLoginFailure(message: "Keychain 로그인 정보 갱신 실패 (\(status))")
        }
        var added = fields
        added[kSecValueData as String] = data
        added[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let created = SecItemAdd(added as CFDictionary, nil)
        guard created == errSecSuccess else {
            throw ServerLoginFailure(message: "Keychain 로그인 정보 저장 실패 (\(created))")
        }
    }

    static func remove(_ configuration: RemoteGameConfiguration) throws {
        let status = SecItemDelete(query(configuration) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ServerLoginFailure(message: "Keychain 로그인 정보 삭제 실패 (\(status))")
        }
    }
}

/// No disk HTTP cache/cookies, and never forward credentials on redirects.
final class ServerTransport: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let delegate = ServerTransport()
    static let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
enum ServerAuthentication {
    static func deviceID() -> UUID {
        if let value = UUID(uuidString: UserDefaults.standard.string(forKey: "ppb.server.device") ?? "") {
            return value
        }
        let value = UUID()
        UserDefaults.standard.set(value.uuidString, forKey: "ppb.server.device")
        return value
    }

    static func login(url: URL, email: String, password: String, register: Bool,
                      linkCode: String = "", deviceID: UUID) async throws -> ServerCredential {
        var body = ["email": email, "password": password, "device_id": deviceID.uuidString]
        body["device_name"] = String((Host.current().localizedName ?? "Mac").prefix(60))
        if register && !linkCode.isEmpty { body["link_code"] = linkCode }
        let data = try await request(url: url, path: register ? "auth/register" : "auth/login", body: body)
        let credential = try JSONDecoder().decode(ServerCredential.self, from: data)
        guard credential.device_id == deviceID, !credential.access_token.isEmpty else {
            throw ServerLoginFailure(message: "로그인 응답의 기기 정보가 맞지 않습니다.")
        }
        return credential
    }

    static func logout(configuration: RemoteGameConfiguration, credential: ServerCredential,
                       all: Bool = false) async throws {
        do {
            _ = try await request(url: configuration.baseURL, path: all ? "auth/logout-all" : "auth/logout",
                                  credential: credential)
        } catch let error as ServerLoginFailure where error.message == loginRequired {
            // An expired/revoked session cannot be used again; clear local credentials.
        }
        try ServerCredentialStore.remove(configuration)
    }

    static func changePassword(configuration: RemoteGameConfiguration, credential: ServerCredential,
                               current: String, new: String) async throws {
        _ = try await request(url: configuration.baseURL, path: "auth/change-password",
            body: ["current_password": current, "new_password": new], credential: credential)
        try ServerCredentialStore.remove(configuration)
    }

    static let loginRequired = "로그인이 필요하거나 세션이 만료됐습니다. 같은 계정으로 다시 로그인하세요."

    static func request(url: URL, path: String, body: [String: Any] = [:],
                        credential: ServerCredential? = nil, method: String = "POST") async throws -> Data {
        guard RemoteGameConfiguration.validURL(url) else {
            throw ServerLoginFailure(message: "원격 서버는 HTTPS 주소가 필요합니다.")
        }
        var request = URLRequest(url: url.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method != "GET" { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        if let credential {
            request.setValue("Bearer \(credential.access_token)", forHTTPHeaderField: "Authorization")
            request.setValue(credential.device_id.uuidString, forHTTPHeaderField: "X-PPB-Device-ID")
        }
        if let gateway = ProcessInfo.processInfo.environment["PPB_GATEWAY_KEY"], !gateway.isEmpty {
            request.setValue(gateway, forHTTPHeaderField: "X-PPB-Gateway-Key")
        }
        let (data, response) = try await ServerTransport.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let detail = object?["detail"] as? String
            let message: String
            switch detail {
            case "invalid_credentials": message = "이메일 또는 비밀번호가 올바르지 않습니다."
            case "invalid_recovery": message = "이메일 또는 복구 코드가 올바르지 않거나 이미 사용됐습니다."
            case "device_not_found": message = "기기 목록이 바뀌었습니다. 새로고침하세요."
            case "login_required": message = loginRequired
            case "link_code_invalid": message = "연결 코드가 만료됐거나 이미 사용됐습니다. 서버에서 새 코드를 발급하세요."
            case "registration_unavailable": message = "해당 정보로 가입할 수 없습니다. 기존 계정이면 로그인하세요."
            case "too_many_attempts": message = "시도가 너무 많습니다. 1분 후 다시 시도하세요."
            default:
                message = status == 422 ? "이메일 형식과 비밀번호 길이(가입 시 \(ServerPasswordPolicy.lengthDescription))를 확인하세요."
                    : "인증 서버 응답 \(status). 주소와 서버 상태를 확인하세요."
            }
            throw ServerLoginFailure(message: message)
        }
        return data
    }
}
