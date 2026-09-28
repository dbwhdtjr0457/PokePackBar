import Foundation

/// 카드의 실제 시세. 배포에 담긴 스냅샷이다.
///
/// **일부러 실시간이 아니다.** 시세는 날마다 움직이는데, 그것을 그대로 물리면 자던 사이에
/// 팩값이 오르고 갖고 있던 카드의 값이 떨어진다. 버전마다 값을 고정해 두면 무엇이 언제
/// 바뀌었는지가 분명하고, 업데이트 자체가 「시세 갱신」이 된다.
///
/// 기본 출처는 TCGplayer 시장가(달러). 시장가가 없는 일부 카드는 출처·기준일·종류를
/// 명시한 실거래 기반 참고가를 사용하며, 시장가와 구별해 표시한다. v2 스냅샷은 카드 번호별
/// 대표값만 갖고 있고, 이후 스냅샷은 normal·reverse holo 같은 인쇄본 값을 함께 가질 수 있다.
/// 인쇄본 값이 없는 옛 스냅샷에서는 카드 대표값으로 자연스럽게 폴백한다.
struct CardPrices: Sendable {

    /// 스냅샷 기준일(`yyyy-MM-dd`). 비어 있으면 표시하지 않는다.
    let asOf: String
    /// 값의 통화. 지금은 USD 하나뿐이지만, 화면이 이 값을 보고 기호를 고른다.
    let currency: String
    /// 1달러가 몇 원인가. 표기용이라 시세와 함께 스냅샷에 고정한다 —
    /// 환율만 실시간이면 카드값이 저 혼자 움직인다.
    let krwPerUSD: Double
    /// 판형 시세만 따로 갱신한 기준일. 없으면 전체 카드 스냅샷 날짜를 쓴다.
    let printingAsOf: String?
    let snapshotDigest: String
    let printingDates: [String: String]
    let printingSources: [String: String]
    let priceDates: [String: String]
    let priceSources: [String: String]
    let priceKinds: [String: String]
    let printingKinds: [String: String]
    var printingCount: Int { byPrinting.count }

    private let byID: [String: Double]
    /// `CardPrintingKey.storageKey` → 해당 인쇄본 시세.
    private let byPrinting: [String: Double]

    /// 카드 한 장의 시세. 모르는 카드는 nil — 0 을 돌려주면 "공짜 카드" 로 보인다.
    func price(_ cardID: String) -> Double? { byID[cardID] }

    /// 특정 인쇄본의 시세. 정확한 값이 없으면 옛 스냅샷의 카드 대표값으로 폴백한다.
    func price(cardID: String, finish: CardFinish) -> Double? {
        byPrinting[CardPrintingKey(cardID: cardID, finish: finish).storageKey] ?? byID[cardID]
    }

    /// 스냅샷에 그 판형이 실제로 따로 실렸을 때만 돌려준다.
    /// 기대값 계산은 이 값으로 병렬판형 프리미엄만 더해야 한다. 폴백 가격을 정확한
    /// 판형 시세처럼 다시 더하면 같은 카드값을 두 번 세게 된다.
    func exactPrice(cardID: String, finish: CardFinish) -> Double? {
        byPrinting[CardPrintingKey(cardID: cardID, finish: finish).storageKey]
    }

    func sourceDate(cardID: String, finish: CardFinish?) -> String {
        guard let finish, exactPrice(cardID: cardID, finish: finish) != nil else { return priceDates[cardID] ?? asOf }
        let key = CardPrintingKey(cardID: cardID, finish: finish).storageKey
        return printingDates[key] ?? (printingAsOf?.isEmpty == false ? printingAsOf! : asOf)
    }

    func isReference(cardID: String, finish: CardFinish?) -> Bool {
        guard let finish, exactPrice(cardID: cardID, finish: finish) != nil else {
            return priceKinds[cardID] == "completed-sales-estimate"
        }
        return printingKinds[CardPrintingKey(cardID: cardID, finish: finish).storageKey] == "completed-sales-estimate"
    }

    func sourceURL(cardID: String, finish: CardFinish?) -> String? {
        guard let finish, exactPrice(cardID: cardID, finish: finish) != nil else { return priceSources[cardID] }
        return printingSources[CardPrintingKey(cardID: cardID, finish: finish).storageKey]
    }

    func price(_ printing: CardPrintingKey) -> Double? {
        price(cardID: printing.cardID, finish: printing.finish)
    }

    /// 갖고 있는 만큼의 값. 장수가 0 이면 nil.
    func total(_ cardID: String, count: Int) -> Double? {
        guard count > 0, let one = price(cardID) else { return nil }
        return one * Double(count)
    }

    /// 특정 인쇄본을 갖고 있는 만큼의 값. 장수가 0 이면 nil.
    func total(cardID: String, finish: CardFinish, count: Int) -> Double? {
        guard count > 0, let one = price(cardID: cardID, finish: finish) else { return nil }
        return one * Double(count)
    }

    /// 원화로 환산한 값. **100원 칸에 맞춘다.**
    ///
    /// 카드에 적히는 값은 그 카드를 팔 때 받는 값과 **같은 숫자**여야 한다. 표기와 판매가가
    /// 각자 반올림하면 757원이라 적어 두고 800원을 주는 일이 생긴다. 그래서 표기도 판매가와
    /// 같은 길(토큰으로 옮겼다가 되돌리기)을 지난다.
    func krw(_ usd: Double) -> Int {
        MarketEconomy.won(tokens: MarketEconomy.tokens(usd: usd, prices: self), prices: self)
    }

    // MARK: 표시

    /// 원화를 앞에, 달러를 괄호에. "120만원 ($869)" 처럼 읽힌다.
    ///
    /// 주 단위가 원이다 — 값을 가늠하는 것은 원 쪽이고, 달러는 출처가 미국 시세라는
    /// 근거로 남긴다. 끝자리를 끊는 규칙은 `WonFormatter` 가 갖고 있다.
    func formattedWithKRW(_ value: Double, language: AppLanguage) -> String {
        "\(WonFormatter.money(krw(value), language: language)) (\(formatted(value)))"
    }

    /// 화면에 쓸 문자열. 값의 크기에 따라 소수점을 줄인다 —
    /// $868.56 은 두 자리가 의미 있지만 $1,466.00 에서는 소수점이 잡음이다.
    func formatted(_ value: Double) -> String {
        let symbol = currency == "USD" ? "$" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        formatter.minimumFractionDigits = value >= 100 ? 0 : 2
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return symbol.isEmpty ? "\(number) \(currency)" : symbol + number
    }

    // MARK: 읽기

    /// 번들 스냅샷. 하나만 읽어 공유한다 — 카드 격자가 장마다 파싱하면 안 된다.
    static var shared: CardPrices? { PriceSnapshotStore.shared.cards }

    static func loadBundled() -> CardPrices? {
        guard let url = AppResources.bundle?.url(forResource: "card-prices", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLog.write("card prices missing from bundle")
            return nil
        }
        return decode(data)
    }

    static func decode(_ data: Data) -> CardPrices? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            AppLog.write("card prices decode failed")
            return nil
        }
        guard payload.currency == "USD", payload.krwPerUsd.isFinite,
              (1...100_000).contains(payload.krwPerUsd), !payload.cardPrices.isEmpty,
              payload.cardPrices.values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 10_000_000 }),
              payload.printingPrices.values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 10_000_000 }) else { return nil }
        return CardPrices(asOf: payload.asOf, currency: payload.currency,
                          krwPerUSD: payload.krwPerUsd, printingAsOf: payload.printingAsOf,
                          snapshotDigest: OpeningRules.digest(data),
                          printingDates: payload.printingDates, printingSources: payload.printingSources,
                          priceDates: payload.priceDates,
                          priceSources: payload.priceSources, priceKinds: payload.priceKinds,
                          printingKinds: payload.printingKinds,
                          byID: payload.cardPrices,
                          byPrinting: payload.printingPrices)
    }

    private struct Payload: Decodable {
        let asOf: String
        let currency: String
        let krwPerUsd: Double
        let printingAsOf: String?
        let cardPrices: [String: Double]
        let printingPrices: [String: Double]
        let printingDates: [String: String]
        let printingSources: [String: String]
        let priceDates: [String: String]
        let priceSources: [String: String]
        let priceKinds: [String: String]
        let printingKinds: [String: String]

        private enum CodingKeys: String, CodingKey {
            case version, asOf, currency, krwPerUsd, prices
            case printingPrices
            case pricesByFinish
            case finishPrices
            case printingPriceSnapshot
            case printingDates, printingSources, priceDates
            case priceSources, priceKinds, printingKinds
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            _ = try? c.decode(Int.self, forKey: .version)
            asOf = try c.decode(String.self, forKey: .asOf)
            currency = try c.decode(String.self, forKey: .currency)
            krwPerUsd = try c.decode(Double.self, forKey: .krwPerUsd)
            printingAsOf = (try? c.decode(PriceSnapshot.self,
                                           forKey: .printingPriceSnapshot))?.asOf
            printingDates = (try? c.decode([String: String].self, forKey: .printingDates)) ?? [:]
            printingSources = (try? c.decode([String: String].self, forKey: .printingSources)) ?? [:]
            priceDates = (try? c.decode([String: String].self, forKey: .priceDates)) ?? [:]
            priceSources = (try? c.decode([String: String].self, forKey: .priceSources)) ?? [:]
            priceKinds = (try? c.decode([String: String].self, forKey: .priceKinds)) ?? [:]
            printingKinds = (try? c.decode([String: String].self, forKey: .printingKinds)) ?? [:]

            var cards: [String: Double] = [:]
            var printings: [String: Double] = [:]

            // v2: `prices` 는 [cardID: Double]. 이후 포맷에서는 같은 자리의 값을
            // [cardID: [finish: Double]] 로 넓혀도 읽을 수 있다. 혼합 맵도 허용한다.
            let primary = (try? c.decode([String: PriceValue].self, forKey: .prices)) ?? [:]
            for (key, value) in primary {
                switch value {
                case .card(let price):
                    if key.contains("#") {
                        let printing = CardPrintingKey(storageKey: key)
                        printings[printing.storageKey] = price
                    } else {
                        cards[key] = price
                    }
                case .finishes(let values):
                    Self.merge(values, cardID: key, cards: &cards, printings: &printings)
                }
            }

            // 명시적인 새 필드도 받는다. flat 맵은 storage key, nested 맵은
            // cardID → finish → price 형식이다. 별칭 둘은 importer 전환 기간 호환용이다.
            if let flat = try? c.decode([String: Double].self, forKey: .printingPrices) {
                for (key, price) in flat {
                    let printing = CardPrintingKey(storageKey: key)
                    printings[printing.storageKey] = price
                }
            } else if let nested = try? c.decode([String: [String: Double]].self,
                                                 forKey: .printingPrices) {
                for (cardID, values) in nested {
                    Self.merge(values, cardID: cardID, cards: &cards, printings: &printings)
                }
            }
            for key in [CodingKeys.pricesByFinish, .finishPrices] {
                guard let nested = try? c.decode([String: [String: Double]].self, forKey: key)
                else { continue }
                for (cardID, values) in nested {
                    Self.merge(values, cardID: cardID, cards: &cards, printings: &printings)
                }
            }

            // 인쇄본 전용 스냅샷도 기존 `price(cardID)` 호출부를 깨뜨리지 않는다.
            // 이미 대표값이 있으면 그대로 둔다. Master Ball이 추가됐다는 이유로 일반 카드
            // 추첨까지 전부 Master Ball 가격이 되면 기대값과 판매가가 부풀기 때문이다.
            // 대표값이 전혀 없는 printing-only 포맷에서만 가장 비싼 판형을 호환값으로 쓴다.
            let cardsWithRepresentative = Set(cards.keys)
            for (storageKey, price) in printings {
                let cardID = CardPrintingKey(storageKey: storageKey).cardID
                guard !cardsWithRepresentative.contains(cardID) else { continue }
                cards[cardID] = max(cards[cardID] ?? 0, price)
            }
            cardPrices = cards
            printingPrices = printings
        }

        private struct PriceSnapshot: Decodable { let asOf: String }

        private static func merge(_ values: [String: Double], cardID: String,
                                  cards: inout [String: Double],
                                  printings: inout [String: Double]) {
            for (rawFinish, price) in values {
                if rawFinish == "default" || rawFinish == "aggregate" {
                    cards[cardID] = price
                    continue
                }
                // 아직 앱이 모르는 새 finish여도 대표 가격에서는 잃지 않는다.
                cards[cardID] = max(cards[cardID] ?? 0, price)
                guard let finish = CardFinish(rawValue: rawFinish) else { continue }
                let key = CardPrintingKey(cardID: cardID, finish: finish)
                printings[key.storageKey] = price
            }
        }
    }

    private enum PriceValue: Decodable {
        case card(Double)
        case finishes([String: Double])

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let card = try? value.decode(Double.self) {
                self = .card(card)
                return
            }
            self = .finishes(try value.decode([String: Double].self))
        }
    }
}
