import Foundation

/// 트레이너 레벨. **연 팩 수가 곧 경험치다.**
///
/// 지금까지 연 팩(`GameState.packsOpened`, 평생 누적)으로 레벨이 정해지므로 기존 사용자는
/// 이미 연 만큼 레벨이 올라 있다. 레벨이 오르면 팩, 쿠폰, 칭호를 받고, 처음 시작한 사람에게는
/// 오리파와 대량 개봉이 차례로 열린다.
///
/// **서버가 같은 값을 계산한다**(`ppb-server/app/native_levels.py`). 그래서 실수 계산을 쓰지
/// 않는다 — 맥과 리눅스의 수학 라이브러리가 마지막 자리에서 달라지면 레벨 경계가 어긋난다.
enum LevelRules {
    static let maxLevel = 100

    /// 레벨 n 에 닿는 데 필요한 누적 개봉 팩 수. 2n(n−1) 이다.
    ///
    /// 2레벨 4팩, 5레벨 40팩, 10레벨 180팩, 20레벨 760팩, 50레벨 4,900팩, 100레벨 19,800팩.
    /// 앞은 촘촘해 시작하자마자 몇 번 오르고, 뒤로 갈수록 대량 개봉을 하는 사람의 목표가 된다.
    static func packsRequired(for level: Int) -> Int {
        let level = min(max(level, 1), maxLevel)
        return 2 * level * (level - 1)
    }

    static func level(forPacksOpened packs: Int) -> Int {
        var level = 1
        while level < maxLevel, packs >= packsRequired(for: level + 1) { level += 1 }
        return level
    }

    // MARK: 보상

    /// 보상 팩이 나오는 세트. 레벨마다 차례로 돈다.
    ///
    /// 「마지막에 연 팩」으로 주면 비싼 옛 팩을 하나 열고 레벨 보상을 받는 것이 최적이 된다.
    /// 값이 고른 최근 본편 세트만 두고 레벨 번호로 정해, 서버도 같은 세트를 고른다.
    /// 새 세트가 나오면 여기와 서버 목록에 함께 붙인다.
    static let rewardSetIDs = ["sv1", "sv2", "sv3", "sv4", "sv5", "sv6", "sv7", "sv8",
                               "sv9", "sv10", "me1", "me2"]

    /// 칭호가 열리는 레벨.
    static let titleLevels = [10, 25, 50, 75, 100]

    struct Reward: Equatable, Sendable {
        let level: Int
        let setID: String
        let packs: Int
        /// 5레벨마다 같은 세트의 반값 쿠폰.
        let couponCount: Int
        let couponValue: Double
        let unlocksTitle: Bool
    }

    static func reward(for level: Int) -> Reward {
        let setID = rewardSetIDs[(level * 7) % rewardSetIDs.count]
        let packs = min(5, 1 + level / 10)
        let milestone = level % 5 == 0
        return Reward(level: level, setID: setID, packs: packs,
                      couponCount: milestone ? 2 : 0, couponValue: 0.5,
                      unlocksTitle: titleLevels.contains(level))
    }

    // MARK: 처음 시작한 사람에게 차례로 여는 것

    /// 오리파는 팩을 몇 번 열어 본 뒤에 연다. 처음부터 있으면 팩과 오리파 중 무엇을 해야
    /// 하는지부터 고민하게 된다. 3레벨은 12팩이다.
    static let oripaLevel = 3

    /// 한 번에 열 수 있는 팩 수. nil 이면 제한이 없다.
    ///
    /// 처음에는 한 장씩 넘기며 개봉을 익히게 둔다. 레벨이 오를 때마다 늘어난다.
    static func openLimit(level: Int) -> Int? {
        if level < 5 { return 10 }
        if level < 10 { return 100 }
        return nil
    }

    /// 다음으로 열리는 기능의 레벨. 다 열렸으면 nil.
    static func nextUnlock(after level: Int) -> Int? {
        [oripaLevel, 5, 10].first { $0 > level }
    }
}
