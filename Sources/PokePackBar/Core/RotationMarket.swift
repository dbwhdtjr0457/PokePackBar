import Foundation

/// 로테이션 마켓. 날마다 카드 8장을 한 장씩 시세에 판다.
///
/// 팩은 무엇이 나올지 모르고, 오리파는 봉투를 고를 뿐이다. 「이 카드가 갖고 싶다」를 바로
/// 풀 길이 없었다. 진열은 날마다 바뀌고 장마다 한 번만 살 수 있어, 오늘 무엇이 올라왔는지
/// 들여다볼 이유가 생긴다.
///
/// **진열은 날짜로 정한다.** UTC 날짜를 시드로 고정 난수(SplitMix64)를 돌리므로 오프라인에서도
/// 같은 진열이 나오고, 서버(`ppb-server/app/native_rotation.py`)도 같은 8장을 고른다. 고르는
/// 데 시세를 쓰지 않는다 — 서버와 앱의 시세가 하루쯤 어긋나도 진열은 같아야 한다.
enum RotationMarket {
    static let slots = 8

    /// 진열 칸의 등급 묶음. 위에서부터 1장, 3장, 4장을 고른다.
    static let top: Set<CardTier> = [.specialArtRare, .ultraRare, .hyperRare, .shinyUltra,
                                     .megaUltraRare, .blackWhiteRare, .futureUltra, .shining, .megaAttack]
    static let middle: Set<CardTier> = [.artRare, .superRare, .characterRare, .tripleRare, .radiant,
                                        .amazing, .shiny, .aceSpec, .prismStar]
    static let low: Set<CardTier> = [.doubleRare]
    static let plan: [(tiers: Set<CardTier>, count: Int)] = [(top, 1), (middle, 3), (low, 4)]

    /// 진열이 바뀌는 기준의 날짜(UTC, `yyyy-MM-dd`). 한국 시간으로 오전 9시에 바뀐다.
    static func dateKey(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// 다음 진열까지 남은 시간.
    static func untilNextLineup(_ date: Date = Date()) -> TimeInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return next.timeIntervalSince(date)
    }

    /// 그날의 8장. 같은 날짜면 언제 어디서 불러도 같다.
    static func lineup(date: String, index: CardIndex) -> [String] {
        var generator = PackSeedGenerator(seed: seed(date))
        let ordered = index.cards.sorted { $0.id < $1.id }
        var picked: [String] = []
        for (tiers, count) in plan {
            var pool = ordered.filter { tiers.contains($0.tier) }.map(\.id)
            for _ in 0..<count where !pool.isEmpty {
                let choice = Int(generator.next() % UInt64(pool.count))
                picked.append(pool.remove(at: choice))
            }
        }
        return picked
    }

    /// 판매가. 시세의 1.2배를 100원 칸에 맞춘다.
    ///
    /// 시세 그대로 팔면 사서 바로 갈아 차익을 낼 수 있다 — 판매에는 도감 혜택으로 최대 15%가
    /// 더 붙는다. 그보다 넉넉히 높여 되팔기가 남는 장사가 되지 않게 한다.
    static func price(cardID: String, finish: CardFinish, prices: CardPrices? = CardPrices.shared) -> Int {
        let base = MarketEconomy.tokens(usd: MarketEconomy.usd(cardID: cardID, finish: finish, prices: prices),
                                        prices: prices)
        return MarketEconomy.quantized((base * 6 + 2) / 5, prices: prices)
    }

    /// 구매 기록에 남기는 열쇠. 날짜와 카드를 함께 적어, 내일 같은 카드가 다시 올라와도 살 수 있다.
    static func purchaseKey(date: String, cardID: String) -> String { "\(date)|\(cardID)" }

    /// FNV-1a 64비트. Swift 의 `Hasher` 는 실행할 때마다 값이 바뀌어 쓸 수 없다.
    static func seed(_ date: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in Array("rotation:\(date)".utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }
}
