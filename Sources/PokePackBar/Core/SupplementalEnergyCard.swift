import Foundation

/// Sun & Moon 이후 부스터에 세트 카드 10장과 별도로 들어가는 기본 에너지.
///
/// 이 카드는 실제 봉입물이라 개봉 화면에는 보여 주되, 확장팩 번호가 없는 별도 인쇄물이므로
/// 도감·보유량·시세·천장 계산에는 넣지 않는다. ID 접두사가 그 경계를 강제한다.
enum SupplementalEnergyCard {
    static let idPrefix = "supplement-energy-"

    enum Style: String, CaseIterable, Sendable {
        case sunMoon = "sm"
        case swordShield = "swsh"
        case scarletViolet = "sve"
        /// 영문 MEE 001–008. 30주년 YOSHIROTTEN 도안과 다르다.
        case megaEvolution = "mee"
        /// 영문 MEE 009–016, 30주년 로고가 있는 YOSHIROTTEN 도안.
        case anniversary = "mee30"
    }

    enum EnergyType: String, CaseIterable, Sendable {
        case grass, fire, water, lightning, psychic, fighting, darkness, metal, fairy

        func displayName(_ language: AppLanguage) -> String {
            let names: [AppLanguage: String]
            switch self {
            case .grass:
                names = [.ko: "기본 풀 에너지", .en: "Basic Grass Energy", .ja: "基本草エネルギー",
                         .es: "Energía Planta básica", .fr: "Énergie Plante de base", .pt: "Energia de Grama Básica"]
            case .fire:
                names = [.ko: "기본 불꽃 에너지", .en: "Basic Fire Energy", .ja: "基本炎エネルギー",
                         .es: "Energía Fuego básica", .fr: "Énergie Feu de base", .pt: "Energia de Fogo Básica"]
            case .water:
                names = [.ko: "기본 물 에너지", .en: "Basic Water Energy", .ja: "基本水エネルギー",
                         .es: "Energía Agua básica", .fr: "Énergie Eau de base", .pt: "Energia de Água Básica"]
            case .lightning:
                names = [.ko: "기본 번개 에너지", .en: "Basic Lightning Energy", .ja: "基本雷エネルギー",
                         .es: "Energía Rayo básica", .fr: "Énergie Électrique de base", .pt: "Energia Elétrica Básica"]
            case .psychic:
                names = [.ko: "기본 초 에너지", .en: "Basic Psychic Energy", .ja: "基本超エネルギー",
                         .es: "Energía Psíquica básica", .fr: "Énergie Psy de base", .pt: "Energia Psíquica Básica"]
            case .fighting:
                names = [.ko: "기본 투 에너지", .en: "Basic Fighting Energy", .ja: "基本闘エネルギー",
                         .es: "Energía Lucha básica", .fr: "Énergie Combat de base", .pt: "Energia de Luta Básica"]
            case .darkness:
                names = [.ko: "기본 악 에너지", .en: "Basic Darkness Energy", .ja: "基本悪エネルギー",
                         .es: "Energía Oscura básica", .fr: "Énergie Obscurité de base", .pt: "Energia de Escuridão Básica"]
            case .metal:
                names = [.ko: "기본 강철 에너지", .en: "Basic Metal Energy", .ja: "基本鋼エネルギー",
                         .es: "Energía Metálica básica", .fr: "Énergie Métal de base", .pt: "Energia Metálica Básica"]
            case .fairy:
                names = [.ko: "기본 페어리 에너지", .en: "Basic Fairy Energy", .ja: "基本フェアリーエネルギー",
                         .es: "Energía Hada básica", .fr: "Énergie Fée de base", .pt: "Energia de Fada Básica"]
            }
            return names[language] ?? names[.en]!
        }
    }

    struct Descriptor: Equatable, Sendable {
        let style: Style
        let type: EnergyType
    }

    static func descriptor(cardID: String) -> Descriptor? {
        guard cardID.hasPrefix(idPrefix) else { return nil }
        let parts = cardID.dropFirst(idPrefix.count).split(separator: "-", maxSplits: 1)
        guard parts.count == 2, let style = Style(rawValue: String(parts[0])),
              let type = EnergyType(rawValue: String(parts[1])) else { return nil }
        return Descriptor(style: style, type: type)
    }

    static func displayName(cardID: String, language: AppLanguage) -> String? {
        descriptor(cardID: cardID)?.type.displayName(language)
    }

    static func data(cardID: String) -> Data? {
        guard let descriptor = descriptor(cardID: cardID), let bundle = AppResources.bundle else { return nil }
        // 검증된 영문 원본만 선택한다. 확장자 fallback으로 이전 일본어 PNG/WebP를
        // 다시 읽지 않으며, MEE 파일명에도 언어를 명시한다.
        let isMega = descriptor.style == .megaEvolution || descriptor.style == .anniversary
        let name = "\(descriptor.style.rawValue)\(isMega ? "-en" : "")-\(descriptor.type.rawValue)"
        let ext = descriptor.style == .scarletViolet ? "png" : "jpg"
        guard let url = bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "supplement-energy")
        else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// 검증된 영문 원본은 모두 약 733×1024. 썸네일은 허용하지 않는다.
    static func accepts(_ data: Data) -> Bool {
        guard let size = CardArtLibrary.dimensions(data) else { return false }
        return min(size.width, size.height) >= 650 && max(size.width, size.height) >= 900
    }

    static func cards(setID: String, era: PackEra, supplement: PackSupplement,
                      expansionCards: [PulledCard]) -> [PulledCard] {
        guard supplement.energyCount > 0 else { return [] }
        let style = style(setID: setID, era: era)
        let types = style == .sunMoon ? EnergyType.allCases : EnergyType.allCases.filter { $0 != .fairy }
        let start = stableIndex(setID: setID, cards: expansionCards, upperBound: types.count)
        return (0..<supplement.energyCount).map { offset in
            let type = types[(start + offset) % types.count]
            return PulledCard(
                id: "\(idPrefix)\(style.rawValue)-\(type.rawValue)",
                tier: .energy,
                isNew: false,
                finish: supplement.holoEnergy ? .holo : .normal
            )
        }
    }

    static func randomCard(setID: String, era: PackEra, finish: CardFinish,
                           using generator: inout some RandomNumberGenerator) -> PulledCard {
        let selectedStyle = style(setID: setID, era: era)
        let types = selectedStyle == .sunMoon
            ? EnergyType.allCases
            : EnergyType.allCases.filter { $0 != .fairy }
        let type = types[Int.random(in: 0..<types.count, using: &generator)]
        return PulledCard(
            id: "\(idPrefix)\(selectedStyle.rawValue)-\(type.rawValue)",
            tier: .energy,
            isNew: false,
            finish: finish
        )
    }

    private static func style(setID: String, era: PackEra) -> Style {
        if setID == "cel30" { return .anniversary }
        if setID.hasPrefix("me") { return .megaEvolution }
        switch era {
        case .sunMoon: return .sunMoon
        case .swordShield: return .swordShield
        default: return .scarletViolet
        }
    }

    /// Swift의 `Hasher`는 실행마다 씨앗이 달라진다. 같은 개봉 결과가 언제나 같은 에너지로
    /// 재현되도록 고정 FNV-1a를 쓴다.
    static func stableIndex(setID: String, cards: [PulledCard], upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in ([setID] + cards.map(\.id)).joined(separator: "|").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(upperBound))
    }
}

extension PulledCard {
    var isSupplementalEnergy: Bool {
        SupplementalEnergyCard.descriptor(cardID: id) != nil
    }
}
