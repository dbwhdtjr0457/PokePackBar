import Foundation
import XCTest
@testable import PokePackBar

/// 로테이션은 상점에서 온라인 마켓으로 옮겼다. 서버가 판매자 없는 매물로 올린다.
@MainActor
final class MarketRotationTests: XCTestCase {

    /// 판매자가 없으니 서버는 이름을 비워 보낸다. 화면이 언어에 맞춰 이름과 표시를 단다.
    func testRotationListingIsNamedAndMarkedByTheApp() {
        let rotation: [String: Any] = ["rotation": true, "bought": false, "nickname": "", "mine": false]
        XCTAssertEqual(OnlineMarketView.seller(rotation), OnlineText.l.rotationSeller)
        XCTAssertEqual(OnlineMarketView.badge(rotation)?.text, OnlineText.l.rotationBadge)

        var bought = rotation
        bought["bought"] = true
        XCTAssertEqual(OnlineMarketView.badge(bought)?.text, OnlineText.l.rotationBought)

        let player: [String: Any] = ["nickname": "지우", "mine": false]
        XCTAssertEqual(OnlineMarketView.seller(player), "지우")
        XCTAssertNil(OnlineMarketView.badge(player))
        XCTAssertEqual(OnlineMarketView.badge(["mine": true])?.text, OnlineText.l.mySales)
    }

    /// 예전 세이브에 남은 로테이션 구매 기록은 읽어도 무시되고, 다시 저장하면 사라진다.
    func testLegacyRotationLedgerIsDropped() throws {
        let legacy = Data(#"{"cards":{"sv1-1":2},"rotationPurchases":["2026-10-08|sv1-1"]}"#.utf8)
        let state = try JSONDecoder().decode(GameState.self, from: legacy)
        XCTAssertEqual(state.cards["sv1-1"], 2)
        let saved = try XCTUnwrap(String(data: JSONEncoder().encode(state), encoding: .utf8))
        XCTAssertFalse(saved.contains("rotationPurchases"))
    }
}
