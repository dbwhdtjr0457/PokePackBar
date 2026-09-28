import Foundation

/// A physical printing treatment, independent from a card's rarity.
///
/// A `Rare` can be normal, holo, or reverse holo, and the same card number can
/// exist in more than one finish. Keep this value on the pulled printing rather
/// than deriving ownership or price from `CardTier`.
enum CardFinish: String, Codable, Sendable, CaseIterable {
    case normal
    case holo
    case reverseHolo
    case patternedReverse
    case fullArt
    case etched
    case radiant
    case amazingRare
    case rainbow
    case gold
    case shiny
    case shinyFullArt
    case aceSpec
    case pokeBall
    case masterBall
    case celebrationsClassic
    case radiantCollection
    case prism
    case breakFoil
    case blackWhite
    case megaAttack

    var foilSpec: FoilSpec {
        switch self {
        case .normal:
            return FoilSpec(coverage: .none, pattern: .none, texture: .paper,
                            border: .paper, intensity: 0)
        case .holo:
            return FoilSpec(coverage: .artWindow, pattern: .cosmos, texture: .none,
                            border: .paper, intensity: 0.50)
        case .reverseHolo:
            return FoilSpec(coverage: .outsideArt, pattern: .reverse, texture: .fineLines,
                            border: .silver, intensity: 0.48)
        case .patternedReverse:
            return FoilSpec(coverage: .outsideArt, pattern: .mirror, texture: .none,
                            border: .silver, intensity: 0.62, treatment: .ascendedBall)
        case .fullArt:
            return FoilSpec(coverage: .fullCard, pattern: .spectrum, texture: .fineLines,
                            border: .silver, intensity: 0.56)
        case .etched:
            return FoilSpec(coverage: .fullCard, pattern: .line, texture: .none,
                            border: .silver, intensity: 0.70)
        case .radiant:
            return FoilSpec(coverage: .fullCard, pattern: .crosshatch, texture: .none,
                            border: .paper, intensity: 0.62)
        case .amazingRare:
            // The rainbow splash is already printed in each source image and
            // is card-specific. Add only a restrained full-face pearly grain
            // plus the energy/rarity glints drawn by `rainbowSplash`.
            return FoilSpec(coverage: .fullCard, pattern: .rainbowSplash, texture: .none,
                            border: .paper, intensity: 0.46)
        case .rainbow:
            return FoilSpec(coverage: .fullCard, pattern: .rainbow, texture: .etched,
                            border: .silver, intensity: 0.54)
        case .gold:
            return FoilSpec(coverage: .fullCard, pattern: .scarletVioletGold, texture: .none,
                            border: .gold, intensity: 0.86)
        case .shiny:
            return FoilSpec(coverage: .artWindow, pattern: .starfield, texture: .fineLines,
                            border: .silver, intensity: 0.64)
        case .shinyFullArt:
            return FoilSpec(coverage: .fullCard, pattern: .shinyV, texture: .none,
                            border: .silver, intensity: 0.76)
        case .aceSpec:
            return FoilSpec(coverage: .outsideArt, pattern: .magenta, texture: .embossed,
                            border: .magenta, intensity: 0.72)
        case .pokeBall:
            return FoilSpec(coverage: .outsideArt, pattern: .pokeBall, texture: .embossed,
                            border: .silver, intensity: 0.58)
        case .masterBall:
            return FoilSpec(coverage: .outsideArt, pattern: .masterBall, texture: .embossed,
                            border: .silver, intensity: 0.74)
        case .celebrationsClassic:
            return FoilSpec(coverage: .fullCard, pattern: .confetti, texture: .none,
                            border: .silver, intensity: 0.62)
        case .radiantCollection:
            return FoilSpec(coverage: .fullCard, pattern: .satin, texture: .none,
                            border: .holo, intensity: 0.50)
        case .prism:
            return FoilSpec(coverage: .fullCard, pattern: .prism, texture: .none,
                            border: .blackWhite, intensity: 0.58)
        case .breakFoil:
            return FoilSpec(coverage: .fullCard, pattern: .breakGrid,
                            texture: .fineLines, border: .gold, intensity: 0.64)
        case .blackWhite:
            return FoilSpec(coverage: .fullCard, pattern: .monochrome, texture: .etched,
                            border: .blackWhite, intensity: 0.60)
        case .megaAttack:
            return FoilSpec(coverage: .subjectAndAttack, pattern: .comicBurst,
                            texture: .none, border: .holo, intensity: 0.62)
        }
    }
}

/// Stable identity for a physical printing.
///
/// Bare legacy card IDs decode as `.normal`, which makes the storage migration
/// deterministic while new pulls can distinguish normal and parallel copies.
struct CardPrintingKey: Hashable, Codable, Sendable, Identifiable {
    let cardID: String
    let finish: CardFinish

    init(cardID: String, finish: CardFinish = .normal) {
        self.cardID = cardID
        self.finish = finish
    }

    init(storageKey: String) {
        guard let separator = storageKey.lastIndex(of: "#") else {
            self.init(cardID: storageKey)
            return
        }

        let rawFinish = String(storageKey[storageKey.index(after: separator)...])
        guard let finish = CardFinish(rawValue: rawFinish) else {
            self.init(cardID: storageKey)
            return
        }

        self.init(cardID: String(storageKey[..<separator]), finish: finish)
    }

    var storageKey: String { "\(cardID)#\(finish.rawValue)" }
    var id: String { storageKey }
}

enum FoilCoverage: String, Codable, Sendable, CaseIterable {
    case none
    case artWindow
    /// EX Hidden Legends / FireRed & LeafGreen rare parallels: art foil plus
    /// one type or Poké Ball impression in the lower attack box.
    case artWindowAndMark
    case artAndBorder
    case artBackground
    case artSubject
    case artSubjectAndBorder
    case artNameAndBorder
    case outsideArt
    case fullCard
    case splash
    case stoneSurface
    case traitBands
    /// Mega Attack cards: etched Pokémon art plus glossy attack-name bands.
    case subjectAndAttack
}

enum FoilPattern: String, Codable, Sendable, CaseIterable {
    case none
    // Standard Holo sheets, in English release order.
    case starlight
    case cosmos
    case tinsel
    case sheen
    case waterWeb
    case verticalLine
    case mirage

    // Reverse/parallel sheets. These are deliberately separate because their
    // direction, motif and coverage changed repeatedly between expansions.
    case reverse
    case fireworks
    case mirror
    case energySymbols
    case energyTypeStamp
    case energyPokeBallStamp
    case energySetStamp
    case pokeBallStamp
    case rocketStamp
    case pinwheel
    case pokeBallStars
    case pokeBall3D
    case stampedMirror
    case cosmosStamp
    case subjectStamp
    case typeSymbols
    case sunMoonSymbols
    case swordShieldTiles
    case scarletVioletTiles
    case splitTypeSymbols

    // Rule-box and full-art coatings.
    case crackedIce
    case refractor
    case stone
    case prime
    case legend
    case celebrationSheen
    case aceDiamond
    case starSheen
    case doubleRareSheen
    case teraSheen
    case vstarSheen
    case satin
    case specialIllustration
    case vmaxRays
    case spectrum
    case line
    case crosshatch
    case rainbowSplash
    case rainbow
    case gold
    case bwGold
    case xyGold
    case sunMoonGold
    case swordShieldGold
    case scarletVioletGold
    case teraGold
    case starfield
    case shinyGX
    case shinyV
    case shinyVMAX
    case shinyEx
    case teraShinyEx
    case magenta
    case pokeBall
    case masterBall
    case confetti
    case prism
    case breakGrid
    case megaGold
    case monochrome
    case blackEtched
    case whiteEtched
    case comicBurst
    case futuristic
}

enum FoilTexture: String, Codable, Sendable, CaseIterable {
    case none
    case paper
    case fineLines
    case etched
    case bwEtched
    case xyEtched
    case sunMoonEtched
    case swordShieldEtched
    case scarletVioletEtched
    case crosshatch
    case embossed
    case shatteredGlass
}

enum FoilBorder: String, Codable, Sendable, CaseIterable {
    case paper
    case silver
    case holo
    case rainbow
    case gold
    case magenta
    case blackWhite
}

/// Rendering recipe for one physical finish.
struct FoilSpec: Equatable, Codable, Sendable {
    let coverage: FoilCoverage
    let pattern: FoilPattern
    let texture: FoilTexture
    let border: FoilBorder
    /// Relative optical strength in the closed range `0...1`.
    let intensity: Double
    /// A compound printing has independent regions/materials. Optional keeps
    /// older decoded diagnostics and existing finish storage identities valid.
    var treatment: FoilTreatment? = nil

    var isFoil: Bool { coverage != .none && intensity > 0 }
}

enum FoilTreatment: String, Codable, Sendable {
    case classic30, pikachu30, futuristic30, rgb30, ascendedEnergy, ascendedBall, megaDoubleRare
}

struct ResolvedCardFinish: Equatable, Codable, Sendable {
    let finish: CardFinish
    let spec: FoilSpec
}

/// Converts source metadata to a physical finish without treating rarity as
/// the printing identity. An explicit finish always wins; the remaining rules
/// only provide a backwards-compatible default for data that predates variants.
enum CardFinishResolver {
    static func resolve(
        cardID: String? = nil,
        setID: String,
        originalRarity: String?,
        tier: CardTier,
        visualKind: CardVisualKind? = nil,
        explicitFinish: CardFinish? = nil
    ) -> ResolvedCardFinish {
        let finish = explicitFinish ?? inferredFinish(
            cardID: cardID,
            setID: setID,
            originalRarity: originalRarity,
            tier: tier)
        // Subsets (TG/GG/Shiny Vault/Classic Collection) are stored under a
        // parent product set, but their card ID prefix is the physical source
        // sheet. Material lookup must preserve that source identity.
        let sourceSetID = cardID?
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? setID
        let spec = FoilMaterialCatalog.spec(
            finish: finish,
            cardID: cardID,
            setID: sourceSetID,
            originalRarity: originalRarity,
            tier: tier,
            visualKind: visualKind)
        return ResolvedCardFinish(finish: finish, spec: spec)
    }

    private static func inferredFinish(
        cardID: String?,
        setID: String,
        originalRarity: String?,
        tier: CardTier
    ) -> CardFinish {
        let rarity = normalized(originalRarity)
        let sourceSetID = sourceSetID(cardID: cardID, fallback: setID)

        // Printing labels supplied by an importer are more specific than rarity.
        if rarity.contains("master ball") { return .masterBall }
        if rarity.contains("poke ball") { return .pokeBall }
        if rarity.contains("reverse") { return .reverseHolo }
        if rarity.contains("classic collection") || rarity == "classic" {
            return .celebrationsClassic
        }
        if cardID?.hasPrefix("bw11-RC") == true
            || (cardID?.hasPrefix("g1-RC") == true && rarity != "common") {
            return .radiantCollection
        }

        // Exact physical exceptions precede marketing rarity names. The
        // source index calls these simply Rare/Secret even though the booster
        // printing has a specific sheet.
        if isDiamondPearlShiny(cardID) { return .reverseHolo }
        if cardID?.hasPrefix("pl2-RT") == true { return .holo }
        if cardID?.hasPrefix("pl4-AR") == true { return .holo }

        // Trainer/Galarian Gallery non-rule-box cards are full-art replacement
        // hits even though the legacy rarity string merely says "Rare Holo".
        if rarity.contains("trainer gallery")
            && (tier == .characterRare || tier == .artRare) {
            return .fullArt
        }

        if rarity.contains("black white") { return .blackWhite }
        // Mega Hyper Rare(MUR)는 금색 단색 계열이다. 공격명과 컬러 버스트가 강조되는
        // Mega Attack Rare와 같은 판형으로 묶으면 무지개빛이 과하게 올라온다.
        if rarity.contains("mega hyper") { return .gold }
        if rarity.contains("mega attack") { return .megaAttack }
        if rarity.contains("radiant") { return .radiant }
        if rarity.contains("amazing") { return .amazingRare }
        if rarity.contains("ace spec") || rarity == "rare ace" { return .aceSpec }
        if rarity.contains("prism star") { return .prism }
        if rarity == "rare break" { return .breakFoil }
        if rarity.contains("rainbow") { return .rainbow }
        if tier == .shinyUltra && rarity.contains("shiny") { return .shinyFullArt }
        if rarity.contains("shiny") || rarity.contains("shining") || rarity.contains("holo star") {
            return .shiny
        }
        if rarity.contains("hyper rare") { return .gold }
        if rarity == "rare secret" {
            return secretFinish(cardID: cardID, sourceSetID: sourceSetID)
        }
        if rarity.contains("special illustration") { return .etched }
        if rarity.contains("illustration rare") { return .fullArt }
        if rarity.contains("ultra rare") || rarity.contains("rare ultra") { return .etched }

        // 별도 번호 서브셋은 upstream rarity가 본 세트식 이름을 재사용한다. 예를 들어
        // Shining Fates의 Shiny V는 `Rare Holo V`, Trainer Gallery의 일러스트는
        // `Trainer Gallery Rare Holo`라 적혀 있다. 여기서는 부모 pool에 매핑한 tier가
        // 실제 재질을 더 정확히 말하므로 일반 V/Holo 규칙보다 먼저 적용한다.
        if (sourceSetID.hasSuffix("tg") || sourceSetID.hasSuffix("gg"))
            && (rarity.contains("rare holo v") || rarity.contains("vmax")
                || rarity.contains("vstar")) {
            return .etched
        }

        switch tier {
        case .shiny:
            return .shiny
        case .shinyUltra:
            return .shinyFullArt
        case .characterRare, .artRare:
            return .fullArt
        case .specialArtRare:
            return .etched
        default:
            break
        }

        // Standard rule-box hits use foil across the card face rather than the
        // old cosmos treatment confined to the illustration window. VMAX/VSTAR
        // add visible texture; V/GX/EX and Scarlet & Violet Double Rare do not.
        if rarity == "rare holo vmax" || rarity == "rare holo vstar" {
            return .etched
        }
        if rarity == "rare holo ex" {
            return sourceSetID.hasPrefix("ex") ? .holo : .fullArt
        }
        if rarity == "rare holo v" || rarity == "rare holo gx"
            || rarity == "double rare" {
            return .fullArt
        }

        // Every base-set Celebrations card is holo even where the API rarity is
        // plain `Rare`; Classic Collection remains an explicit printing variant.
        if setID == "cel25" || (setID == "cel30" && [.common, .uncommon, .rare].contains(tier)) {
            return .holo
        }
        if rarity.contains("holo") || rarity == "legend" || rarity.contains("prime") {
            return .holo
        }
        if rarity == "rare"
            && (sourceSetID.hasPrefix("sv") || sourceSetID.hasPrefix("rsv")
                || sourceSetID.hasPrefix("zsv") || sourceSetID.hasPrefix("me")) {
            return .holo
        }
        if rarity == "common" || rarity == "uncommon" || rarity == "rare" {
            return .normal
        }

        // Metadata-free fallback. In particular `.rare` stays non-holo: rarity
        // alone is not evidence of a foil printing.
        switch tier {
        case .energy, .common, .uncommon, .rare, .promo:
            return .normal
        case .doubleRare, .tripleRare:
            return .holo
        case .prismStar:
            return .prism
        case .amazing:
            return .amazingRare
        case .radiant:
            return .radiant
        case .characterRare, .artRare:
            return .fullArt
        case .aceSpec:
            return .aceSpec
        case .superRare, .specialArtRare:
            return .etched
        case .shiny, .shining:
            return .shiny
        case .shinyUltra:
            return .shinyFullArt
        case .hyperRare:
            return .rainbow
        case .ultraRare, .megaUltraRare:
            return .gold
        case .blackWhiteRare:
            return .blackWhite
        case .megaAttack:
            return .megaAttack
        case .futureUltra:
            return .etched
        }
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") ?? ""
    }

    private static func sourceSetID(cardID: String?, fallback: String) -> String {
        cardID?
            .split(separator: "-", maxSplits: 1)
            .first
            .map(String.init) ?? fallback
    }

    private static func isDiamondPearlShiny(_ cardID: String?) -> Bool {
        guard let cardID else { return false }
        return cardID.hasPrefix("dp7-SH") || cardID.hasPrefix("pl1-SH")
            || cardID.hasPrefix("pl3-SH") || cardID.hasPrefix("pl4-SH")
    }

    private static func secretFinish(cardID: String?, sourceSetID: String) -> CardFinish {
        guard let cardID else { return .holo }

        if sourceSetID == "xy12" { return .normal }
        if sourceSetID == "sm35" { return .rainbow }
        if sourceSetID == "sm12", let number = numericCardNumber(cardID),
           (237...248).contains(number) {
            return .fullArt
        }
        if cardID == "swsh12pt5-160" { return .fullArt }

        if sourceSetID.hasPrefix("base") || sourceSetID.hasPrefix("ecard")
            || sourceSetID.hasPrefix("ex") || sourceSetID.hasPrefix("dp")
            || sourceSetID.hasPrefix("pl") || sourceSetID.hasPrefix("hgss") {
            return .holo
        }

        if sourceSetID.hasPrefix("bw") {
            let goldTrainerIDs: Set<String> = [
                "bw5-111", "bw7-153", "bw8-138", "bw9-121", "bw9-122",
                "bw10-105", "bw11-114", "bw11-115",
            ]
            return goldTrainerIDs.contains(cardID) ? .gold : .shiny
        }

        if sourceSetID.hasPrefix("xy") {
            let goldItemIDs: Set<String> = [
                "xy5-161", "xy5-162", "xy5-163", "xy5-164",
                "xy6-109", "xy6-110", "xy7-99",
            ]
            return goldItemIDs.contains(cardID) ? .gold : .etched
        }

        return .gold
    }

    private static func numericCardNumber(_ cardID: String) -> Int? {
        guard let separator = cardID.lastIndex(of: "-") else { return nil }
        return Int(cardID[cardID.index(after: separator)...])
    }
}
