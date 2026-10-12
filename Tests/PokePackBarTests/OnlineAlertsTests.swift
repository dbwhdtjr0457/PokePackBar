import Foundation
import XCTest
@testable import PokePackBar

/// 온라인 알림: 무엇을 macOS 알림으로 보내고, 무엇을 다시 보내지 않는가.
@MainActor
final class OnlineAlertsTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var language = AppLanguage.ko

    override func setUp() {
        super.setUp()
        suite = "ppb-alerts-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        language = AppLanguage.current
        AppLanguage.current = .ko
        OnlineText.wallet = nil
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        AppLanguage.current = language
        super.tearDown()
    }

    /// 서버에 몇 번 물었는지 센다.
    private final class Counter { var value = 0 }

    private typealias Summary = RemoteGameSession.NotificationSummary

    private func summary(unread: Int, latest: Int?) -> Summary {
        Summary(unread: unread, incoming_trades: 0, incoming_friends: 0, latest_id: latest)
    }

    /// 서버 흉내. `after` 뒤의 알림을 오래된 순으로 준다.
    private func server(_ items: [[String: Any]], requests: Counter? = nil)
        -> (String) async throws -> Data {
        { path in
            requests?.value += 1
            let after = Int(path.components(separatedBy: "after=").last?.prefix { $0.isNumber } ?? "") ?? 0
            let rest = items.filter { ($0["id"] as? Int ?? 0) > after }
            return try JSONSerialization.data(withJSONObject: ["items": rest, "next_after": NSNull()])
        }
    }

    private func note(_ id: Int, _ kind: String, read: Bool = false, detail: [String: Any] = [:]) -> [String: Any] {
        ["id": id, "kind": kind, "target": "t", "read": read, "created_at": 0, "detail": detail]
    }

    /// 처음 켠 기기는 쌓여 있던 알림을 알리지 않는다. 그 뒤에 온 것부터 알린다.
    func testFirstCheckOnlyMarksThePosition() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        let requests = Counter()
        let sent = await alerts.check(summary: summary(unread: 3, latest: 7), enabled: true,
                                      fetch: server([note(7, "trade_request")], requests: requests))
        XCTAssertTrue(sent.isEmpty)
        XCTAssertEqual(alerts.lastSeen, 7)
        XCTAssertEqual(requests.value, 0, "최신 번호를 아는 서버에서는 목록을 읽을 필요가 없다")
    }

    /// 새로 온 것만 한 번 알리고, 앱을 다시 켜도(같은 저장소) 또 알리지 않는다.
    func testNewArrivalsAreAnnouncedOnce() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        await alerts.check(summary: summary(unread: 0, latest: 3), enabled: true, fetch: server([]))
        let items = [note(3, "friend_request"), note(4, "trade_request", detail: ["nickname": "민수"])]
        let sent = await alerts.check(summary: summary(unread: 1, latest: 4), enabled: true, fetch: server(items))
        XCTAssertEqual(sent.map(\.body), ["민수 님이 교환을 제안했어요"])
        XCTAssertEqual(sent.first?.kind, "trade_request")
        XCTAssertEqual(alerts.lastSeen, 4)

        let restarted = OnlineAlerts(storageKey: "a", defaults: defaults)
        let again = await restarted.check(summary: summary(unread: 1, latest: 4), enabled: true, fetch: server(items))
        XCTAssertTrue(again.isEmpty, "이미 알린 알림을 다시 알렸다")
    }

    /// 이미 읽은 것(새 서버는 내 행동의 알림을 읽음으로 만든다)과 내가 산 기록은 알리지 않는다.
    func testReadAndOwnPurchaseStaySilent() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        await alerts.check(summary: summary(unread: 0, latest: 1), enabled: true, fetch: server([]))
        let items = [note(2, "trade_accepted", read: true), note(3, "listing_bought"), note(4, "listing_sold")]
        let sent = await alerts.check(summary: summary(unread: 2, latest: 4), enabled: true, fetch: server(items))
        XCTAssertEqual(sent.map(\.kind), ["listing_sold"])
    }

    /// 오래 꺼 두었다 켜면 알림이 줄줄이 뜨지 않고 하나로 묶인다.
    func testManyArrivalsCollapseIntoOne() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        await alerts.check(summary: summary(unread: 0, latest: 1), enabled: true, fetch: server([]))
        let items = (2...6).map { note($0, "trade_request", detail: ["nickname": "친구\($0)"]) }
        let sent = await alerts.check(summary: summary(unread: 5, latest: 6), enabled: true, fetch: server(items))
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.title, "새 알림 5개")
        XCTAssertEqual(sent.first?.body, "친구6 님이 교환을 제안했어요 외 4개")
        XCTAssertEqual(sent.first?.kind, "", "묶은 알림은 알림 탭으로 간다")
        XCTAssertEqual(OnlineAlerts.destination(kind: ""), .alerts)
    }

    /// 꺼 두었거나 내가 방금 한 일 뒤에는 알리지 않되, 위치는 넘어간다. 나중에 켰을 때 밀린 것이 쏟아지지 않는다.
    func testDisabledAndQuietChecksStillAdvance() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        await alerts.check(summary: summary(unread: 0, latest: 1), enabled: true, fetch: server([]))
        let off = await alerts.check(summary: summary(unread: 1, latest: 2), enabled: false,
                                     fetch: server([note(2, "trade_request")]))
        XCTAssertTrue(off.isEmpty)
        XCTAssertEqual(alerts.lastSeen, 2)

        alerts.quietNext = true
        let own = await alerts.check(summary: summary(unread: 2, latest: 3), enabled: true,
                                     fetch: server([note(3, "trade_accepted")]))
        XCTAssertTrue(own.isEmpty)
        XCTAssertFalse(alerts.quietNext, "한 번만 조용히 넘긴다")
        let next = await alerts.check(summary: summary(unread: 3, latest: 4), enabled: true,
                                      fetch: server([note(4, "listing_sold")]))
        XCTAssertEqual(next.map(\.kind), ["listing_sold"])
    }

    /// 최신 번호를 주지 않는 예전 서버: 처음에는 끝까지 읽어 위치를 잡고, 그 뒤로는 안 읽은 수가
    /// 늘었을 때만 목록을 읽는다.
    func testOlderServerReadsOnlyWhenUnreadGrows() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        let requests = Counter()
        var items = [note(1, "friend_request"), note(2, "trade_request")]
        await alerts.check(summary: summary(unread: 2, latest: nil), enabled: true,
                           fetch: server(items, requests: requests))
        XCTAssertEqual(alerts.lastSeen, 2)
        let before = requests.value
        let same = await alerts.check(summary: summary(unread: 2, latest: nil), enabled: true,
                                      fetch: server(items, requests: requests))
        XCTAssertTrue(same.isEmpty)
        XCTAssertEqual(requests.value, before, "달라진 것이 없는데 목록을 읽었다")

        items.append(note(3, "listing_sold"))
        let grown = await alerts.check(summary: summary(unread: 3, latest: nil), enabled: true,
                                       fetch: server(items, requests: requests))
        XCTAssertEqual(grown.map(\.kind), ["listing_sold"])
    }

    /// 서버가 이름이나 카드를 보내면 그것으로 말하고, 보내지 않으면 짧은 문장으로 남는다.
    func testTextUsesDetailWhenTheServerSendsIt() throws {
        XCTAssertEqual(OnlineText.notificationText(kind: "trade_request"), "새 교환 제안이 왔어요")
        XCTAssertEqual(OnlineText.notificationText(kind: "friend_accept", nickname: "지우"),
                       "지우 님이 친구 신청을 수락했어요")
        // 거절은 양쪽에 모두 가는 알림이라 「누가 했다」가 아니라 「누구와의 제안이」로 적는다.
        XCTAssertEqual(OnlineText.notificationText(kind: "trade_rejected", nickname: "지우"),
                       "지우 님과의 교환 제안이 거절됐어요")
        XCTAssertNotEqual(OnlineText.notificationText(kind: "friend_remove"), "friend_remove",
                          "서버 종류 이름이 그대로 화면에 나왔다")

        let card = try XCTUnwrap(CardIndex.shared?.cards.first)
        let sold = OnlineText.notificationText(kind: "listing_sold", printing: "\(card.id)#holo", unitTokens: 2_920_000)
        XCTAssertTrue(sold.contains(card.displayName(.ko)), sold)
        XCTAssertTrue(sold.contains("원"), sold)
        // 카드를 모르거나 값이 없으면 짧은 문장.
        XCTAssertEqual(OnlineText.notificationText(kind: "listing_sold", printing: "no-such-card#holo", unitTokens: 1),
                       "올린 카드가 팔렸어요")
        XCTAssertEqual(OnlineText.notificationText(["kind": "trade_request", "detail": ["nickname": "민수"]]),
                       "민수 님이 교환을 제안했어요")
    }

    private func hub() -> OnlineHubModel {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("alerts-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return OnlineHubModel(wallet: WalletStore(fileURL: dir.appendingPathComponent("game-state.json")))
    }

    /// 알림을 누르면 탭만 여는 것이 아니라 그 교환, 판매 글을 찾아간다.
    func testFollowingAnAlertLandsOnTheItem() {
        let model = hub()
        model.follow(kind: "trade_request", target: "trade-1")
        XCTAssertEqual(model.section, .trades)
        XCTAssertEqual(model.focusID, "trade-1")
        // 목록에 그 항목이 들어왔을 때 한 번만 끌어온다. 새로 받을 때마다 끌려가면 안 된다.
        XCTAssertNil(model.takeFocus(among: ["other"]))
        XCTAssertEqual(model.takeFocus(among: ["other", "trade-1"]), "trade-1")
        XCTAssertNil(model.takeFocus(among: ["other", "trade-1"]))

        model.follow(kind: "listing_sold", target: "listing-1")
        XCTAssertEqual(model.section, .market)
        XCTAssertTrue(model.opensMyListings, "팔린 글은 「내 판매」 에서 본다")
        XCTAssertEqual(model.focusID, "listing-1")

        // 묶은 알림은 가리키는 항목이 없다. 알림 탭으로만 가고, 앞서 짚던 것도 거둔다.
        model.follow(kind: "", target: "")
        XCTAssertEqual(model.section, .alerts)
        XCTAssertNil(model.focusID)
    }

    /// 위시리스트 알림은 마켓을 그 카드로 찾아 연다. 걸어 둔 조건에 가려 안 보이면 안 된다.
    func testWishlistAlertSearchesTheMarketForThatCard() throws {
        let card = try XCTUnwrap(CardIndex.shared?.cards.first { $0.nameKo != nil })
        let model = hub()
        model.section = .alerts
        model.marketSet = "base1"
        model.marketTier = "C"
        model.follow(kind: "wishlist_listing", target: "listing-9", printing: "\(card.id)#holo")
        XCTAssertEqual(model.section, .market)
        XCTAssertTrue(model.opensMarketBuy)
        XCTAssertEqual(model.search, card.nameKo)
        XCTAssertEqual(model.marketSet, "")
        XCTAssertEqual(model.marketTier, "")
        XCTAssertEqual(model.focusID, "listing-9")

        // 서버가 아는 이름은 영어와 한국어뿐이다. 다른 언어에서는 영어 이름으로 찾는다.
        AppLanguage.current = .ja
        XCTAssertEqual(OnlineText.searchName("\(card.id)#holo"), card.name)
        AppLanguage.current = .ko

        // 카드를 알려 주지 않는 예전 서버: 찾던 말은 그대로 두고 마켓만 연다.
        let plain = hub()
        plain.section = .alerts
        plain.search = "피카츄"
        plain.follow(kind: "wishlist_listing", target: "listing-9")
        XCTAssertEqual(plain.section, .market)
        XCTAssertEqual(plain.search, "피카츄")
    }

    /// macOS 알림도 눌렀을 때 그 항목을 찾아갈 수 있게 번호와 카드를 싣는다.
    func testAnnouncementCarriesWhereToLand() async {
        let alerts = OnlineAlerts(storageKey: "a", defaults: defaults)
        await alerts.check(summary: summary(unread: 0, latest: 1), enabled: true, fetch: server([]))
        let items = [note(2, "wishlist_listing", detail: ["printing": "no-such-card#holo", "unit_tokens": 5])]
        let sent = await alerts.check(summary: summary(unread: 1, latest: 2), enabled: true, fetch: server(items))
        XCTAssertEqual(sent.first?.target, "t")
        XCTAssertEqual(sent.first?.printing, "no-such-card#holo")
    }

    /// 답할 것이 있는 탭만 개수를 단다. 없으면 이름 그대로다.
    func testTabTitleCarriesWhatIsWaiting() {
        let waiting = Summary(unread: 5, incoming_trades: 1, incoming_friends: 0, latest_id: 9)
        XCTAssertEqual(OnlineText.tabTitle(.alerts, summary: waiting), "알림 5")
        XCTAssertEqual(OnlineText.tabTitle(.trades, summary: waiting), "교환 1")
        XCTAssertEqual(OnlineText.tabTitle(.social, summary: waiting), "친구")
        XCTAssertEqual(OnlineText.tabTitle(.market, summary: waiting), "마켓")
        XCTAssertEqual(OnlineText.tabTitle(.alerts, summary: nil), "알림")
    }

    func testTimeAgoSpeaksInTheLargestUnit() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        func ago(_ seconds: Int) -> String { OnlineText.timeAgo(2_000_000_000 - seconds, now: now) }
        XCTAssertEqual(ago(20), "방금")
        XCTAssertEqual(ago(5 * 60), "5분 전")
        XCTAssertEqual(ago(3 * 3600 + 10), "3시간 전")
        XCTAssertEqual(ago(2 * 86_400), "2일 전")
        XCTAssertFalse(ago(9 * 86_400).contains("일 전"), "일주일이 넘으면 날짜로 적는다")
        XCTAssertEqual(OnlineText.timeAgo(0, now: now), "", "시각을 모르면 아무것도 적지 않는다")
    }

    func testReadAllUsesDisplayedPageBoundary() {
        let displayed: [[String: Any]] = [["id": 9], ["id": 7]]
        let newerSummary = RemoteGameSession.NotificationSummary(
            unread: 3, incoming_trades: 0, incoming_friends: 0, latest_id: 10)
        let boundary = OnlineHubModel.shownNotificationBoundary(displayed)
        XCTAssertEqual(boundary, 9)
        XCTAssertLessThan(boundary ?? 0, newerSummary.latest_id ?? 0)
        XCTAssertNil(OnlineHubModel.shownNotificationBoundary([]))
        XCTAssertNil(OnlineHubModel.shownNotificationBoundary([["id": 0]]))
    }

    /// 교환에 담을 카드는 값으로 견준다. 시세 없는 카드는 어느 가격순에서도 뒤에 온다.
    func testStockSortsByPriceWithUnpricedLast() {
        func stock(_ key: String, _ won: Int?) -> OnlineStock {
            OnlineStock(key: key, cardID: key, finish: .holo, available: 1, referenceWon: won)
        }
        let all = [stock("b", 500), stock("a", nil), stock("c", 9_000), stock("d", 100)]
        XCTAssertEqual(OnlineStockPicker.sorted(all, by: .priceHigh).map(\.key), ["c", "b", "d", "a"])
        XCTAssertEqual(OnlineStockPicker.sorted(all, by: .priceLow).map(\.key), ["d", "b", "c", "a"])
        XCTAssertEqual(OnlineStockPicker.sorted(all, by: .name).map(\.key), ["a", "b", "c", "d"])
    }
}
