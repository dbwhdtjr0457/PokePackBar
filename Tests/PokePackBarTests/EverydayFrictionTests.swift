import Foundation
import XCTest
@testable import PokePackBar

/// Esc 는 한 단계씩 뒤로 간다. 팝오버를 닫는 것은 돌아갈 곳이 없을 때뿐이다.
@MainActor
final class PopoverBackTests: XCTestCase {

    private func handler(_ name: String, into log: @escaping (String) -> Void) -> PopoverBackHandler {
        let handler = PopoverBackHandler()
        handler.action = { log(name) }
        return handler
    }

    /// 가장 나중에 나타난 화면(가장 깊은 화면)이 먼저 받고, 사라지면 그 아래 화면이 받는다.
    func testEscapeGoesBackFromTheDeepestScreen() {
        let nav = PopoverNavigation()
        XCTAssertFalse(nav.goBack(), "돌아갈 곳이 없으면 팝오버가 닫혀야 한다")

        var log: [String] = []
        let list = handler("list") { log.append($0) }
        let detail = handler("detail") { log.append($0) }
        nav.registerBack(list)
        nav.registerBack(detail)

        XCTAssertTrue(nav.goBack())
        XCTAssertEqual(log, ["detail"])

        nav.unregisterBack(detail)
        XCTAssertTrue(nav.goBack())
        XCTAssertEqual(log, ["detail", "list"])

        nav.unregisterBack(list)
        XCTAssertFalse(nav.goBack())
    }

    /// 맨 위 화면에 지금 할 일이 없으면 아래 화면의 뒤로 가기를 부르지 않는다.
    /// 위 화면을 둔 채 아래 화면이 바뀌면 엉뚱한 곳으로 간다.
    func testIdleTopScreenDoesNotReachTheScreenBelow() {
        let nav = PopoverNavigation()
        var log: [String] = []
        nav.registerBack(handler("list") { log.append($0) })
        let idle = PopoverBackHandler()
        nav.registerBack(idle)

        XCTAssertFalse(nav.goBack())
        XCTAssertEqual(log, [])
    }

    /// 같은 화면이 다시 나타나면 맨 위로 올라간다. 두 번 쌓이지 않는다.
    func testRegisteringAgainMovesTheScreenToTheTop() {
        let nav = PopoverNavigation()
        var log: [String] = []
        let list = handler("list") { log.append($0) }
        let detail = handler("detail") { log.append($0) }
        nav.registerBack(list)
        nav.registerBack(detail)
        nav.registerBack(list)

        XCTAssertTrue(nav.goBack())
        XCTAssertEqual(log, ["list"])
        nav.unregisterBack(list)
        XCTAssertTrue(nav.goBack())
        XCTAssertEqual(log, ["list", "detail"])
    }
}

/// 친구 코드는 끊어 보이고, 어떻게 붙여 넣든 서버가 받는 꼴로 보낸다.
final class FriendCodeTests: XCTestCase {

    func testNormalizesSpacingDashesAndCase() {
        XCTAssertEqual(OnlineText.normalizedFriendCode("ab12 cd34-ef56 7890"), "AB12CD34EF567890")
        XCTAssertEqual(OnlineText.normalizedFriendCode("  AB12CD34EF567890\n"), "AB12CD34EF567890")
    }

    /// 공유 문장을 통째로 붙여 넣어도 코드만 골라낸다.
    func testPicksTheCodeOutOfASharedSentence() {
        XCTAssertEqual(OnlineText.normalizedFriendCode("PokePackBar 친구 코드: 1A2B 3C4D 5E6F 7A8B"),
                       "1A2B3C4D5E6F7A8B")
        XCTAssertEqual(OnlineText.normalizedFriendCode("My PokePackBar friend code: 1a2b-3c4d-5e6f-7a8b"),
                       "1A2B3C4D5E6F7A8B")
    }

    func testGroupsInFours() {
        XCTAssertEqual(OnlineText.groupedFriendCode("1A2B3C4D5E6F7A8B"), "1A2B 3C4D 5E6F 7A8B")
        XCTAssertEqual(OnlineText.groupedFriendCode("ABCDEF"), "ABCD EF")
        XCTAssertEqual(OnlineText.groupedFriendCode(""), "")
    }
}

/// 서버가 거절한 이유는 문장으로 보이고, 복구 판단에 쓰는 코드는 그대로 남는다.
@MainActor
final class ServerReasonTests: XCTestCase {

    func testKnownReasonsReadAsSentences() {
        let l = L(.en)
        XCTAssertEqual(l.serverReason("friend_code_unavailable"),
                       "No one has that friend code. Check the code and try again.")
        XCTAssertNotNil(l.serverReason("listing_unavailable"))
        XCTAssertNotNil(l.serverReason("rules_engine_timeout"))
        XCTAssertNil(l.serverReason("something_new_from_the_server"))
        for language in AppLanguage.allCases {
            XCTAssertFalse(L(language).serverReason("insufficient_balance")?.isEmpty ?? true)
        }
    }

    /// `idempotency_key_reused` 는 같은 요청을 다시 보낼지 정하는 데 쓰인다. 문장으로 바꾸면
    /// 그 판단이 깨진다.
    func testDescribeKeepsTheRecoveryCodeAndTranslatesKnownOnes() {
        let reused = RemoteGameSession.describe(status: 409, data: Data(#"{"detail":"idempotency_key_reused"}"#.utf8))
        XCTAssertTrue(reused.contains("idempotency_key_reused"))

        let gone = RemoteGameSession.describe(status: 404, data: Data(#"{"detail":"listing_not_found"}"#.utf8))
        XCTAssertFalse(gone.contains("listing_not_found"))
        XCTAssertEqual(gone, L.current.serverReason("listing_not_found"))

        let unknown = RemoteGameSession.describe(status: 409, data: Data(#"{"detail":"brand_new_reason"}"#.utf8))
        XCTAssertTrue(unknown.contains("brand_new_reason"), "모르는 코드는 찾아볼 수 있게 그대로 붙인다")
    }

    func testNotificationsOpenTheTabThatHandlesThem() {
        XCTAssertEqual(OnlineText.destination("trade_request"), .trades)
        XCTAssertEqual(OnlineText.destination("trade_countered"), .trades)
        XCTAssertEqual(OnlineText.destination("friend_request"), .social)
        XCTAssertEqual(OnlineText.destination("friend_accepted"), .social)
        XCTAssertEqual(OnlineText.destination("listing_sold"), .market)
        XCTAssertEqual(OnlineText.destination("wishlist_listing"), .market)
        XCTAssertNil(OnlineText.destination("maintenance"))
    }
}

/// 실패 문구는 할 일을 말한다. 시스템 문장과 타입 이름은 화면에 그대로 나가지 않는다.
final class ProblemTextTests: XCTestCase {

    func testFileFailuresSayWhatToDo() {
        let l = L.current
        XCTAssertEqual(ProblemText.message(for: CocoaError(.fileWriteOutOfSpace)), l.problemDiskFull)
        XCTAssertEqual(ProblemText.message(for: CocoaError(.fileWriteNoPermission)), l.problemNoPermission)
        XCTAssertEqual(ProblemText.message(for: CocoaError(.fileReadNoSuchFile)), l.problemFileMissing)
        XCTAssertEqual(ProblemText.message(for: CocoaError(.fileReadCorruptFile)), l.problemFileUnreadable)
    }

    func testUnreadableRepliesBecomeAShortNotice() {
        let decoding = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        XCTAssertEqual(ProblemText.message(for: decoding), L.current.unexpectedProblem)
        XCTAssertEqual(ProblemText.message(for: CocoaError(.coderReadCorrupt)), L.current.unexpectedProblem)
    }

    /// 저장 보호와 개봉 실패는 이미 읽을 문장이다. 그대로, 지금 언어로 나간다.
    func testOwnFailuresKeepTheirLocalizedSentence() {
        XCTAssertEqual(ProblemText.message(for: GamePersistence.Failure.newerVersion), L.current.saveNewerVersion)
        XCTAssertEqual(ProblemText.message(for: PreparedPackBatch.Failure.incompleteCatalogue),
                       L.current.packCatalogueIncomplete)
    }
}

/// 큰 구매는 한 번 더 묻는다. 한 팩은 묻지 않는다.
final class PurchaseConfirmationTests: XCTestCase {

    func testAsksOnlyForSeveralPacksThatSpendHalfTheBalance() {
        XCTAssertFalse(PurchaseConfirmation.needed(quantity: 1, total: 900, balance: 1000))
        XCTAssertTrue(PurchaseConfirmation.needed(quantity: 3, total: 500, balance: 1000))
        XCTAssertTrue(PurchaseConfirmation.needed(quantity: 3, total: 1000, balance: 1000))
        XCTAssertFalse(PurchaseConfirmation.needed(quantity: 3, total: 499, balance: 1000))
        XCTAssertFalse(PurchaseConfirmation.needed(quantity: 2, total: 10, balance: 0))
    }

    func testPercentIsRounded() {
        XCTAssertEqual(PurchaseConfirmation.percent(total: 624, balance: 1000), 62)
        XCTAssertEqual(PurchaseConfirmation.percent(total: 625, balance: 1000), 63)
        XCTAssertEqual(PurchaseConfirmation.percent(total: 5, balance: 0), 500)
    }
}
