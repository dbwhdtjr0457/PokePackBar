import Foundation

/// 실제 밀봉 부스터 한 팩의 시장가 스냅샷.
///
/// 카드 기대값과 밀봉 팩 시장가는 서로 다른 값이다. 오래된 팩은 카드 기대값보다
/// 수집품 프리미엄이 훨씬 크므로 단일 부스터 시장가는 가격의 현실 기준이 된다.
/// 다만 낱장 기대값보다 지나치게 낮아 무한 되팔이가 생기는 경우에만 경제 안전 하한이
/// 더 높은 값을 쓴다. 표에 없는 세트는 카드 기대값에서 가격을 만든다.
struct PackMarketPrices: Sendable {

    struct Entry: Decodable, Equatable, Sendable {
        let usd: Double
        let productID: Int
        let productName: String
        let url: String
        var asOf: String? = nil
    }

    let version: Int
    let asOf: String
    let currency: String
    let source: String
    let snapshotDigest: String

    private let bySetID: [String: Entry]

    func entry(setID: String) -> Entry? {
        guard let entry = bySetID[setID], entry.usd > 0 else { return nil }
        return entry
    }

    func price(setID: String) -> Double? {
        entry(setID: setID)?.usd
    }

    static var shared: PackMarketPrices? { PriceSnapshotStore.shared.packs }

    static func loadBundled() -> PackMarketPrices? {
        guard let url = AppResources.bundle?.url(forResource: "pack-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLog.write("pack prices missing from bundle; using expected card value")
            return nil
        }
        return decode(data)
    }

    static func decode(_ data: Data) -> PackMarketPrices? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version > 0,
              !payload.asOf.isEmpty,
              payload.currency == "USD",
              payload.packs.values.allSatisfy({ $0.usd.isFinite && $0.usd > 0 && $0.usd < 10_000_000 }) else {
            AppLog.write("pack prices decode failed; using expected card value")
            return nil
        }
        return PackMarketPrices(version: payload.version,
                                asOf: payload.asOf,
                                currency: payload.currency,
                                source: payload.source,
                                snapshotDigest: OpeningRules.digest(data),
                                bySetID: payload.packs)
    }

    private struct Payload: Decodable {
        let version: Int
        let asOf: String
        let currency: String
        let source: String
        let packs: [String: Entry]
    }
}
