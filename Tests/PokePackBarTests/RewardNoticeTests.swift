import AppKit
import SwiftUI
import XCTest
@testable import PokePackBar

/// 받은 순간의 알림(도감 보상, 온라인 창의 교환과 마켓 표시)은 잠깐 떴다가 스스로 걷힌다.
@MainActor
final class RewardNoticeTests: XCTestCase {
    private var window: NSWindow?

    override func tearDown() {
        window?.close()
        window = nil
        super.tearDown()
    }

    private func makeWallet() -> WalletStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("notice-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return WalletStore(fileURL: dir.appendingPathComponent("game-state.json"))
    }

    private func host(_ view: some View, size: NSSize) {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFrontRegardless()
        controller.view.layoutSubtreeIfNeeded()
        self.window = window
    }

    private func show(_ nav: PopoverNavigation) {
        host(CelebrationLayer(wallet: makeWallet()).environment(nav), size: NSSize(width: 360, height: 600))
    }

    private func notice(_ tokens: Int) -> RewardNotice {
        RewardNotice(reward: DexReward(packs: 0, perks: [], tokens: tokens), homeSet: "base1")
    }

    func testANoticeClearsItself() async throws {
        let nav = PopoverNavigation()
        show(nav)
        nav.rewardNotice = notice(1)
        try await Task.sleep(for: .seconds(3.6))
        XCTAssertNil(nav.rewardNotice, "알림이 걷히지 않았다")
    }

    /// 보상을 잇달아 받으면 먼저 뜬 알림이 걷히기 전에 다음 알림으로 바뀐다. 그 다음 알림도 걷혀야 한다.
    func testANoticeThatReplacesAnotherAlsoClears() async throws {
        let nav = PopoverNavigation()
        show(nav)
        nav.rewardNotice = notice(1)
        try await Task.sleep(for: .seconds(1))
        nav.rewardNotice = notice(2)
        try await Task.sleep(for: .seconds(4.2))
        XCTAssertNil(nav.rewardNotice, "두 번째 알림이 계속 떠 있다")
    }

    /// 온라인 창의 표시도 같다. 잇달아 사거나 판매를 올리면 표시가 바뀌는데, 나중 것도 걷혀야 한다.
    func testAnOnlineCelebrationThatReplacesAnotherAlsoClears() async throws {
        let wallet = makeWallet()
        OnlineText.wallet = wallet
        let model = OnlineHubModel(wallet: wallet)
        host(OnlineHubView(model: model), size: NSSize(width: 740, height: 540))
        model.celebration = OnlineCelebration(kind: .listed(printing: "sv10-1#holo"))
        try await Task.sleep(for: .seconds(1))
        model.celebration = OnlineCelebration(kind: .listed(printing: "sv10-2#holo"))
        try await Task.sleep(for: .seconds(4))
        XCTAssertNil(model.celebration, "두 번째 표시가 계속 떠 있다")
        OnlineText.wallet = nil
    }
}
