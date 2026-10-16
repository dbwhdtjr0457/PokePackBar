import Foundation
import XCTest
@testable import PokePackBar

/// 정식 앱 옆에 개발용 앱을 함께 띄울 때 나뉘는 것들. 정식 앱은 예전 그대로여야 한다.
@MainActor
final class AppVariantTests: XCTestCase {

    /// Info.plist 에 `PPBDataName` 이 없는 정식 앱은 예전 폴더와 파일 이름을 그대로 쓴다.
    /// 바뀌면 업데이트한 사용자의 세이브가 사라진 것처럼 보인다.
    func testOfficialAppKeepsItsDataFolder() {
        XCTAssertEqual(AppEnv.dataName, "PokePackBar")
        XCTAssertEqual(AppEnv.supportDirectory.lastPathComponent, "PokePackBar")
        XCTAssertEqual(WalletStore.defaultURL().deletingLastPathComponent().lastPathComponent,
                       ProcessInfo.processInfo.environment["PPB_STATE_DIR"].map { URL(fileURLWithPath: $0).lastPathComponent }
                           ?? "PokePackBar")
    }

    /// 정식 앱은 업데이트를 확인한다. 개발용 앱만 끈다.
    func testOfficialAppStillChecksForUpdates() {
        XCTAssertFalse(AppLinks.isDevApp)
        XCTAssertEqual(AppLinks.updateChannel, "stable")
        XCTAssertTrue(AppLinks.updatesConfigured)
    }
}
