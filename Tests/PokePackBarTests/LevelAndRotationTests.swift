import Foundation
import XCTest
@testable import PokePackBar

/// 트레이너 레벨. 서버가 같은 식을 쓰므로 값이 바뀌면 서버도 함께 바꿔야 한다.
final class LevelRulesTests: XCTestCase {

    func testCurveIsTwoNNMinusOne() {
        XCTAssertEqual(LevelRules.packsRequired(for: 1), 0)
        XCTAssertEqual(LevelRules.packsRequired(for: 2), 4)
        XCTAssertEqual(LevelRules.packsRequired(for: 10), 180)
        XCTAssertEqual(LevelRules.packsRequired(for: 100), 19_800)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 0), 1)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 3), 1)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 4), 2)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 179), 9)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 180), 10)
        XCTAssertEqual(LevelRules.level(forPacksOpened: 1_000_000), LevelRules.maxLevel)
    }

    /// 보상 세트는 실제로 파는 세트여야 한다. 없는 세트면 받은 팩을 열 수 없다.
    func testRewardSetsExistAndRewardsGrow() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for id in LevelRules.rewardSetIDs {
            XCTAssertNotNil(index.set(id), "\(id) 가 카탈로그에 없다")
        }
        XCTAssertEqual(LevelRules.reward(for: 2).packs, 1)
        XCTAssertEqual(LevelRules.reward(for: 10).packs, 2)
        XCTAssertEqual(LevelRules.reward(for: 90).packs, 5)
        XCTAssertEqual(LevelRules.reward(for: 5).couponCount, 2)
        XCTAssertEqual(LevelRules.reward(for: 6).couponCount, 0)
        XCTAssertTrue(LevelRules.reward(for: 25).unlocksTitle)
        // 서버(native_levels.py)와 같은 세트를 고르는지 고정해 둔다.
        XCTAssertEqual(LevelRules.reward(for: 2).setID, "sv3")
        XCTAssertEqual(LevelRules.reward(for: 13).setID, "sv8")
    }

    func testBeginnersUnlockFeaturesInOrder() {
        XCTAssertEqual(LevelRules.openLimit(level: 1), 10)
        XCTAssertEqual(LevelRules.openLimit(level: 5), 100)
        XCTAssertNil(LevelRules.openLimit(level: 10))
        XCTAssertEqual(LevelRules.nextUnlock(after: 1), LevelRules.oripaLevel)
        XCTAssertNil(LevelRules.nextUnlock(after: 10))
    }
}

/// 로테이션 마켓. 진열은 날짜만으로 정해지고, 서버가 같은 8장을 고른다.
final class RotationMarketTests: XCTestCase {

    func testLineupIsStablePerDayAndFollowsThePlan() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let today = RotationMarket.lineup(date: "2026-10-08", index: index)
        XCTAssertEqual(today, RotationMarket.lineup(date: "2026-10-08", index: index))
        XCTAssertEqual(today.count, RotationMarket.slots)
        XCTAssertEqual(Set(today).count, today.count, "같은 카드가 두 번 올라왔다")
        XCTAssertNotEqual(today, RotationMarket.lineup(date: "2026-10-09", index: index))
        let tiers = try today.map { try XCTUnwrap(index.card($0)).tier }
        XCTAssertTrue(RotationMarket.top.contains(tiers[0]))
        XCTAssertTrue(tiers[1...3].allSatisfy(RotationMarket.middle.contains))
        XCTAssertTrue(tiers[4...].allSatisfy(RotationMarket.low.contains))
    }

    func testSeedMatchesTheServer() {
        // FNV-1a 64("rotation:2026-10-08"). 서버 테스트가 같은 값을 확인한다.
        XCTAssertEqual(RotationMarket.seed("2026-10-08"), RotationMarket.seed("2026-10-08"))
        XCTAssertNotEqual(RotationMarket.seed("2026-10-08"), RotationMarket.seed("2026-10-09"))
    }

    func testDateKeyIsUTC() {
        // 2026-10-08 23:30 UTC 는 한국 시간으로 10월 9일 아침이지만 진열은 아직 10월 8일 것이다.
        let date = Date(timeIntervalSince1970: 1_791_502_200)
        XCTAssertEqual(RotationMarket.dateKey(date), "2026-10-08")
        XCTAssertEqual(RotationMarket.untilNextLineup(date), 1_800, accuracy: 1)
    }

    /// 사서 바로 갈아도 남지 않는다. 판매에는 도감 혜택으로 최대 15%가 더 붙는다.
    func testBuyingAndGrindingNeverPays() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        let prices = try XCTUnwrap(CardPrices.loadBundled())
        for card in RotationMarket.lineup(date: "2026-10-08", index: index) {
            let price = RotationMarket.price(cardID: card, finish: .normal, prices: prices)
            let sale = CardSale.price(cardID: card, prices: prices, perks: DexPerks.caps)
            XCTAssertGreaterThan(price, sale, "\(card): \(price) 에 사서 \(sale) 에 판다")
        }
    }
}

@MainActor
final class LevelWalletTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("level-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func wallet() -> WalletStore {
        WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
    }

    func testLevelRewardsAreGrantedOnce() throws {
        let wallet = wallet()
        XCTAssertTrue(wallet.claimableLevels.isEmpty)
        let index = try XCTUnwrap(CardIndex.shared)
        let need = LevelRules.packsRequired(for: 5)
        for _ in 0..<need { wallet.addPack(setID: "sv1") }
        XCTAssertNotNil(wallet.openPacks(setID: "sv1", count: need, index: index))
        XCTAssertEqual(wallet.level, 5)
        XCTAssertEqual(wallet.claimableLevels, [2, 3, 4, 5])
        let rewards = wallet.claimLevels()
        XCTAssertEqual(rewards.map(\.level), [2, 3, 4, 5])
        let packs = rewards.reduce(0) { $0 + $1.packs }
        XCTAssertEqual(wallet.totalPackCount, packs)
        XCTAssertEqual(wallet.activeCoupons.reduce(0) { $0 + $1.left }, 2, "5레벨 쿠폰")
        XCTAssertTrue(wallet.claimableLevels.isEmpty)
        XCTAssertTrue(wallet.claimLevels().isEmpty, "같은 보상을 두 번 받았다")
    }

    func testRotationCardSellsOncePerDay() throws {
        let index = try XCTUnwrap(CardIndex.shared)
        let wallet = wallet()
        let card = try XCTUnwrap(wallet.rotationLineup(index: index).last)
        let price = wallet.rotationPrice(card, index: index)
        wallet.creditReportedTokens(price * 3)
        let before = wallet.availableTokens
        XCTAssertNotNil(wallet.buyRotation(cardID: card, index: index))
        XCTAssertEqual(wallet.availableTokens, before - price)
        XCTAssertEqual(wallet.cardCount(card), 1)
        XCTAssertTrue(wallet.rotationBought(card))
        XCTAssertNil(wallet.buyRotation(cardID: card, index: index), "한 장을 두 번 샀다")
        XCTAssertNil(wallet.buyRotation(cardID: card, index: index, date: "2000-01-01"),
                     "지난 진열로 샀다")
    }
}
