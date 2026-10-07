import XCTest
@testable import PokePackBar

@MainActor
final class RemoteStateValidationTests: XCTestCase {
    func testBackgroundSnapshotDecodeRejectsInvalidLedgerBeforePublication() async throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "account_id": UUID().uuidString, "revision": 1, "balance": 0,
            "state": ["cards": [:], "usedSinceInstall": -1]
        ])
        do {
            _ = try await RemoteGameSession.decoded(RemoteGameSession.Snapshot.self, from: data)
            XCTFail("A rejected cache write must not leave an invalid wallet in memory")
        } catch {}
    }

    func testPatchValidationRejectsInvalidLedgerAndRetainsBaseState() throws {
        let account = UUID().uuidString
        let base = RemoteGameSession.Snapshot(account_id: account, revision: 1,
            balance: 0, state: GameState(), state_digest: "base")
        let patch: [String: Any] = [
            "account_id": account, "revision": 2, "balance": 0,
            "set": ["usedSinceInstall": -1], "merge": [:], "remove": []
        ]
        XCTAssertThrowsError(try RemoteGameSession.applying(patch, to: base))
        XCTAssertEqual(base.state.usedSinceInstall, 0)
        XCTAssertEqual(base.revision, 1)
    }
}
