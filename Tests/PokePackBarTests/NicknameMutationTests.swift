import XCTest
@testable import PokePackBar

@MainActor
final class NicknameMutationTests: XCTestCase {
    func testNicknameEditPreservesNestedPrivacyAndProfileRevision() throws {
        let reply: [String: Any] = ["revision": 42, "profile": [
            "nickname": "Before", "collection_public": true, "wishlist_public": false,
            "binder_public": true, "trade_list_public": false,
        ]]
        let body = try OnlineSettingsView.nicknameMutation("After", from: reply)
        XCTAssertEqual(body["nickname"] as? String, "After")
        XCTAssertEqual(body["expected_revision"] as? Int, 42)
        XCTAssertEqual(body["collection_public"] as? Bool, true)
        XCTAssertEqual(body["wishlist_public"] as? Bool, false)
        XCTAssertEqual(body["binder_public"] as? Bool, true)
        XCTAssertEqual(body["trade_list_public"] as? Bool, false)
        XCTAssertNotNil(UUID(uuidString: body["request_id"] as? String ?? ""))
    }

    func testMalformedProfileCannotResetPrivacyChoices() {
        XCTAssertThrowsError(try OnlineSettingsView.nicknameMutation("After", from: ["revision": 1]))
        XCTAssertThrowsError(try OnlineSettingsView.nicknameMutation("After", from: ["profile": [:]]))
    }
}
