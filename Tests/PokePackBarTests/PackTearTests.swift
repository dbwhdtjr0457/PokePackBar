import XCTest
@testable import PokePackBar

/// 팩 뜯기 화면이 첫 장 화면으로 이어지는 자리와, 찢긴 선의 모양.
@MainActor
final class PackTearTests: XCTestCase {

    /// 꺼낸 카드가 멈추는 모습이 첫 장이 등장을 시작하는 밑장 자리와 같아야 한다.
    /// 어긋나면 화면이 넘어가는 순간 카드가 튄다.
    func testExtractedCardStopsOnTheRevealDeckPose() {
        XCTAssertEqual(PackTearMetrics.risenScale * PackTearMetrics.settleScale,
                       RevealPeek.deckScale, accuracy: 1e-9)
        XCTAssertEqual(PackTearMetrics.risenOffset + PackTearMetrics.settleOffset,
                       Double(RevealPeek.deckOffset), accuracy: 1e-9)
    }

    /// 무대는 공개 화면의 카드와 같은 크기이고, 팩은 그 안에 들어간다.
    func testStageMatchesTheRevealCard() {
        XCTAssertEqual(PackTearMetrics.stageWidth, RevealPeek.cardWidth)
        XCTAssertEqual(PackTearMetrics.stageHeight, (RevealPeek.cardWidth / 0.717).rounded())
        XCTAssertLessThanOrEqual(PackTearMetrics.packHeight, PackTearMetrics.stageHeight)
        XCTAssertLessThanOrEqual(PackTearMetrics.packWidth, PackTearMetrics.stageWidth)
    }

    /// 팩 안에 있는 동안 카드는 찢는 선 아래에 숨어 있어야 한다. 뜯기 전에 비치면 스포일러다.
    func testCardStartsHiddenBelowTheTearLine() {
        let cardHalfHeight = Double(PackTearMetrics.stageHeight) * PackTearMetrics.insideScale / 2
        let cardTop = PackTearMetrics.insideOffset - cardHalfHeight
        let tearY = (PackTearMetrics.tearLine - 0.5) * Double(PackTearMetrics.packHeight)
        XCTAssertGreaterThan(cardTop, tearY)
        XCTAssertLessThanOrEqual(PackTearMetrics.insideOffset + cardHalfHeight,
                                 Double(PackTearMetrics.packHeight) / 2)
    }

    /// 같은 세트는 언제나 같은 모양으로 찢어지고, 선은 팩 폭을 끝까지 가로지른다.
    func testTearEdgeIsStableAndSpansThePack() {
        let seed = PackTearEdge.seed("sv1")
        let first = PackTearEdge.points(seed: seed)
        XCTAssertEqual(first, PackTearEdge.points(seed: seed))
        XCTAssertNotEqual(first, PackTearEdge.points(seed: PackTearEdge.seed("base1")))
        XCTAssertEqual(first.first?.x, 0)
        XCTAssertEqual(first.last?.x, 1)
        XCTAssertTrue(zip(first, first.dropFirst()).allSatisfy { $0.x < $1.x })
        XCTAssertTrue(first.allSatisfy { abs($0.y - PackTearMetrics.tearLine) < 0.02 })
    }

    /// 밀어서 찢는 양은 처음 민 방향으로만 늘고, 끝까지 밀면 1 에서 멈춘다.
    func testTearFollowsTheFirstDirection() {
        let reach = PackTearMetrics.packWidth * PackTearMetrics.tearReach
        XCTAssertEqual(PackTearMetrics.tearAmount(reach / 2, fromLeading: true), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PackTearMetrics.tearAmount(-reach / 2, fromLeading: true), 0)
        XCTAssertEqual(PackTearMetrics.tearAmount(-reach / 2, fromLeading: false), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PackTearMetrics.tearAmount(reach * 3, fromLeading: true), 1)
    }

    /// 흔들림은 손을 대면 잦아들어 완전히 멈춘다. 꺼내는 동안 팩이 기울어 있으면 첫 장과 어긋난다.
    func testAmbientMotionSettlesToRest() {
        let still = PackTearClock.ambient(time: 1.7, amplitude: 0)
        XCTAssertEqual(still.yaw, 0)
        XCTAssertEqual(still.roll, 0)
        XCTAssertEqual(still.lift, 0)
        var clock = PackTearClock()
        let now = Date()
        clock.settle(now: now)
        let settled = clock.ambient(at: now.addingTimeInterval(PackTearClock.calmDuration + 0.01))
        XCTAssertEqual(settled.yaw, 0, accuracy: 1e-9)
        XCTAssertEqual(settled.lift, 0, accuracy: 1e-9)
    }
}
