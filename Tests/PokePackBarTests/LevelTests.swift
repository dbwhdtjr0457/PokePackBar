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
}
