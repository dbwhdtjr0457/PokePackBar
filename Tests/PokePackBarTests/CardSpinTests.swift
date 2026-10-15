import Foundation
import XCTest
@testable import PokePackBar

/// 카드를 끌어 돌리는 규칙. 화면 없이 각도 계산만 본다.
final class CardSpinTests: XCTestCase {

    /// 카드 폭만큼 좌우로 끌면 반 바퀴. 위아래는 한계에서 멈춘다.
    func testDraggingTurnsHalfAWidthPerCardWidth() {
        let turned = CardSpin.rest.turned(by: CGSize(width: 200, height: 1_000), width: 200)
        XCTAssertEqual(turned.yaw, 180, accuracy: 0.001)
        XCTAssertEqual(turned.pitch, CardSpin.pitchLimit, accuracy: 0.001)
        XCTAssertEqual(CardSpin.rest.turned(by: CGSize(width: -50, height: -20), width: 200).yaw, -45, accuracy: 0.001)
    }

    /// 옆으로 서는 90도를 넘으면 뒷면이 보인다. 한 바퀴를 넘겨도 마찬가지다.
    func testFaceFlipsPastTheEdge() {
        XCTAssertTrue(CardSpin(yaw: 89, pitch: 0).showsFront)
        XCTAssertFalse(CardSpin(yaw: 91, pitch: 0).showsFront)
        XCTAssertFalse(CardSpin(yaw: -180, pitch: 20).showsFront)
        XCTAssertTrue(CardSpin(yaw: 350, pitch: 0).showsFront)
    }

    /// 놓으면 가장 가까운 앞면이나 뒷면에 기울기 없이 선다. 두 번 누르면 가장 가까운 앞면.
    func testReleaseSettlesOnTheNearestFace() {
        XCTAssertEqual(CardSpin(yaw: 100, pitch: 20).settled, CardSpin(yaw: 180, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 80, pitch: -10).settled, CardSpin(yaw: 0, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 500, pitch: 0).settled, CardSpin(yaw: 540, pitch: 0))
        XCTAssertEqual(CardSpin(yaw: 200, pitch: 5).front, CardSpin(yaw: 360, pitch: 0))
        XCTAssertTrue(CardSpin(yaw: 540, pitch: 0).isSettled)
        XCTAssertFalse(CardSpin(yaw: 30, pitch: 0).isSettled)
    }

    /// 뒷면 그림은 리소스에 들어 있고 카드와 같은 비율이다. 없으면 어두운 판으로 바뀌어
    /// 화면은 깨지지 않지만, 빠진 줄 모르고 지나가면 안 된다.
    func testCardBackShipsWithTheApp() throws {
        let image = try XCTUnwrap(CardBackImage.image, "Resources/card-back.webp 를 읽지 못했다")
        XCTAssertEqual(image.size.width / image.size.height, 0.717, accuracy: 0.01)
    }

    /// 도는 동안 넘기는 광택 기울기는 정면과 옆으로 선 순간에 0 이다. 그래야 정면에서는 지금과
    /// 같은 모습이고, 옆으로 설 때 더 기운 앞면의 뒤쪽이 비치지 않는다.
    func testSpinLightIsQuietFaceOnAndEdgeOn() {
        XCTAssertEqual(CardSpin.rest.lightTilt.nx, 0, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 90, pitch: 0).lightTilt.nx, 0, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 45, pitch: 0).lightTilt.nx, 0.9, accuracy: 0.001)
        XCTAssertEqual(CardSpin(yaw: 0, pitch: CardSpin.pitchLimit).lightTilt.ny, 0.9, accuracy: 0.001)
    }
}
