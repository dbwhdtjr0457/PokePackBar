import XCTest
@testable import PokePackBar

@MainActor
final class RemoteGameSessionTests: XCTestCase {
    private func withRoot(_ operation: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-session-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try operation(root)
    }

    private func configuration(account: UUID = UUID(), device: UUID = UUID()) -> RemoteGameConfiguration {
        RemoteGameConfiguration(baseURL: URL(string: "https://ppb-api.wonyangs.com")!,
                                accountID: account, deviceID: device)
    }

    private func collector(_ config: RemoteGameConfiguration, root: URL) throws -> GameState {
        try GamePersistence(url: root.appendingPathComponent(
            "online-\(config.storageKey)/device-collection.json")).load().state
    }

    func testFirstOnlineObservationDoesNotRecreditExistingUsage() throws {
        try withRoot { root in
            let config = configuration()
            let session = RemoteGameSession(configuration: config, localRoot: root, tokenProvider: { nil })
            session.recordUsage(["codex": 800_000], date: "2026-09-30", hasData: true)
            XCTAssertFalse(session.awaitingFirstUsage)
            XCTAssertEqual(try collector(config, root: root).usedSinceInstall, 0)
            session.recordUsage(["codex": 800_100], date: "2026-09-30", hasData: true)
            XCTAssertEqual(try collector(config, root: root).usedSinceInstall, 100)
        }
    }

    func testSameDeviceRestoresCollectorAndOnlyAccruesUnseenIncrement() throws {
        try withRoot { root in
            let config = configuration()
            let first = RemoteGameSession(configuration: config, localRoot: root, tokenProvider: { nil })
            first.recordUsage(["codex": 100], date: "2026-09-30", hasData: true)
            first.recordUsage(["codex": 300], date: "2026-09-30", hasData: true)
            let restored = RemoteGameSession(configuration: config, localRoot: root, tokenProvider: { nil })
            XCTAssertFalse(restored.awaitingFirstUsage)
            restored.recordUsage(["codex": 300], date: "2026-09-30", hasData: true)
            XCTAssertEqual(try collector(config, root: root).usedSinceInstall, 200)
            restored.recordUsage(["codex": 350], date: "2026-09-30", hasData: true)
            XCTAssertEqual(try collector(config, root: root).usedSinceInstall, 250)
        }
    }

    func testNewDeviceDoesNotReplayAnotherDevicesUsageOrPendingRequest() throws {
        try withRoot { root in
            let firstConfig = configuration()
            let first = RemoteGameSession(configuration: firstConfig, localRoot: root, tokenProvider: { nil })
            first.recordUsage(["codex": 100], date: "2026-09-30", hasData: true)
            first.recordUsage(["codex": 1_000], date: "2026-09-30", hasData: true)
            let pending = RemoteGameSession.Request(request_id: UUID(), expected_revision: 1,
                command: .init(kind: "report_tokens", collected_total: 900), rules_version: "test")
            let pendingURL = root.appendingPathComponent("online-\(firstConfig.storageKey)/pending.json")
            try JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)

            let newConfig = configuration(account: firstConfig.accountID)
            let newDevice = RemoteGameSession(configuration: newConfig, localRoot: root, tokenProvider: { nil })
            XCTAssertNotEqual(firstConfig.storageKey, newConfig.storageKey)
            XCTAssertTrue(newDevice.awaitingFirstUsage)
            XCTAssertFalse(newDevice.hasPending)
            newDevice.recordUsage(["codex": 1_100], date: "2026-09-30", hasData: true)
            XCTAssertEqual(try collector(newConfig, root: root).usedSinceInstall, 0)
            XCTAssertEqual(try collector(firstConfig, root: root).usedSinceInstall, 900)
            XCTAssertTrue(FileManager.default.fileExists(atPath: pendingURL.path))

            let resumed = RemoteGameSession(configuration: firstConfig, localRoot: root, tokenProvider: { nil })
            XCTAssertTrue(resumed.hasPending, "The original device must retain its uncertain request")
        }
    }

    func testOnlineCollectionDoesNotModifyTheLocalSave() throws {
        try withRoot { root in
            let localURL = root.appendingPathComponent("game-state.json")
            let local = WalletStore(fileURL: localURL)
            local.addPack(setID: "base1", count: 2)
            let original = try Data(contentsOf: localURL)
            let session = RemoteGameSession(configuration: configuration(), localRoot: root, tokenProvider: { nil })
            session.recordUsage(["codex": 100], date: "2026-09-30", hasData: true)
            session.recordUsage(["codex": 200], date: "2026-09-30", hasData: true)
            XCTAssertEqual(try Data(contentsOf: localURL), original)
        }
    }
}
