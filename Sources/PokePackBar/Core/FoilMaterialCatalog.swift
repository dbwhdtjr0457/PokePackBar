import Foundation

/// English Pokémon TCG foil-sheet catalogue.
///
/// `CardFinish` remains the stable storage identity so existing collections and
/// printing prices keep working. The actual optical material is resolved from
/// the expansion as well: a Base Set holo and a Scarlet & Violet holo are both
/// owned as `holo`, but they no longer render with the same foil sheet.
enum FoilMaterialCatalog {
    // Earlier sets predate expansion-foil.json. They must use the same Mega
    // material as later Mega RR cards, not the ordinary ex star sheet.
    static let earlyMegaDoubleRareIDs: Set<String> = [
        "me1-3", "me1-22", "me1-36", "me1-50", "me1-60", "me1-77",
        "me1-86", "me1-94", "me1-100", "me1-104",
        "me2-4", "me2-13", "me2-41", "me2-56", "me2-61", "me2-84",
    ]

    static func spec(
        finish: CardFinish,
        cardID: String?,
        setID: String,
        originalRarity: String?,
        tier: CardTier,
        visualKind: CardVisualKind? = nil
    ) -> FoilSpec {
        let rarity = normalized(originalRarity)
        let cardID = cardID ?? ""

        if let special = ExpansionFoil.spec(cardID: cardID, finish: finish) {
            return special
        }
        if finish == .fullArt, earlyMegaDoubleRareIDs.contains(cardID) {
            return FoilSpec(coverage: .fullCard, pattern: .mirage, texture: .scarletVioletEtched,
                border: .silver, intensity: 0.60, treatment: .megaDoubleRare)
        }

        switch finish {
        case .holo:
            // 팩에 끼워 주는 holo 기본 에너지(30주년, BW/WF 갓팩)는 카드 목록에 없는 ID라
            // 세트가 "supplement" 로 읽혀 Cosmos(그림 창) 기본값에 떨어졌다. 에너지 카드에는
            // 그림 창이 없고, 실물 30주년 에너지는 카드 전체가 포일이다. 스캔 분석이 필요 없는
            // 전면 가로 홀로라 공개 순간 바로 그려진다.
            if cardID.hasPrefix(SupplementalEnergyCard.idPrefix) {
                return foil(.fullCard, .mirage, .none, .silver, 0.50)
            }
            return standardHolo(cardID: cardID, setID: setID, rarity: rarity)
        case .reverseHolo:
            return reverseHolo(cardID: cardID, setID: setID, rarity: rarity)
        case .fullArt:
            return fullArt(cardID: cardID, setID: setID, rarity: rarity,
                           visualKind: visualKind)
        case .etched:
            return etched(cardID: cardID, setID: setID, rarity: rarity, tier: tier,
                          visualKind: visualKind)
        case .shiny:
            return shiny(cardID: cardID, setID: setID, rarity: rarity)
        case .shinyFullArt:
            return shinyFullArt(setID: setID, rarity: rarity,
                                visualKind: visualKind)
        case .gold:
            return gold(setID: setID, rarity: rarity, visualKind: visualKind)
        case .rainbow:
            return rainbow(setID: setID)
        case .aceSpec:
            return aceSpec(setID: setID)
        case .radiantCollection:
            return radiantCollection(cardID: cardID, setID: setID)
        case .prism:
            // Prism Stars are SM holo rares: the set's water-web sheet shows
            // through the art window and the large diamond in the text box.
            return foil(.artWindowAndPrismStar, .waterWeb, .none, .blackWhite, 0.58)
        case .breakFoil:
            return foil(.fullCard, .breakGrid, .fineLines, .gold, 0.58)
        case .blackWhite:
            return blackWhite(cardID: cardID)
        case .megaAttack:
            // `comicBurst` owns two different fixed geometries: fine relief in
            // the art/subject zone and glossy stripes over attack-name bands.
            // A second generic etched layer would collapse them together.
            return foil(.subjectAndAttack, .comicBurst, .none, .holo, 0.62)
        case .patternedReverse:
            return ExpansionFoil.parallels[cardID] == nil ? CardFinish.normal.foilSpec : finish.foilSpec
        case .normal, .radiant, .amazingRare, .pokeBall, .masterBall,
             .celebrationsClassic:
            return finish.foilSpec
        }
    }

    // MARK: Standard holo sheets

    private static func standardHolo(cardID: String, setID: String,
                                     rarity: String) -> FoilSpec {
        // Preserve legacy collection/price keys while correcting their optics.
        // The upstream index labels this gold Secret Rare as ordinary Rare Holo.
        if cardID == "cel25-25" {
            return gold(setID: "cel25", rarity: "rare secret", visualKind: nil)
        }
        if cardID == "cel25-5" {
            // Untextured full-art Pikachu: the source-bound window covers all
            // printed artwork but excludes its ordinary yellow paper frame.
            return foil(.artWindow, .celebrationSheen, .none, .paper, 0.56)
        }
        if isAlphLithograph(cardID) {
            return foil(.stoneSurface, .stone, .embossed, .paper, 0.32)
        }
        if hasBakedCrackedIceScan(cardID) {
            if cardID.hasPrefix("pl2-RT") {
                return foil(.outsideArt, .crackedIce, .shatteredGlass, .paper, 0.54)
            }
            return foil(.fullCard, .crackedIce, .shatteredGlass, .holo, 0.54)
        }
        if rarity == "legend" {
            return foil(.fullCard, .legend, .etched, .holo, 0.54)
        }
        if rarity.contains("prime") {
            return foil(.artNameAndBorder, .prime, .etched, .gold, 0.51)
        }
        if rarity.contains("lv.x") {
            return foil(.artAndBorder, .cosmos, .fineLines, .holo, 0.52)
        }
        if rarity == "rare holo ex" && setID.hasPrefix("ex") {
            return foil(.artAndBorder, .cosmos, .none, .holo, 0.52)
        }
        if (setID == "ex11" || setID == "ex15") && rarity == "rare holo" {
            // Only the Pokémon and metallic frame carry the refractor sheet.
            // Subject contours are stored against each original image hash.
            return foil(.artSubjectAndBorder, .refractor, .none, .holo, 0.51)
        }
        if setID == "col1" && cardID.contains("-SL") {
            return foil(.artAndBorder, .cosmos, .fineLines, .silver, 0.54)
        }

        switch setID {
        case "base1", "base2", "base3":
            // Base, Jungle and Fossil: soft multi-size starbursts in the art box.
            return foil(.artWindow, .starlight, .none, .paper, 0.58)

        case let id where id.hasPrefix("bw"):
            // Black & White through Legendary Treasures: horizontal tinsel.
            return foil(.artWindow, .tinsel, .none, .paper, 0.50)

        case "xy12":
            // Evolutions deliberately recreates the large Base-era star sheet.
            return foil(.artWindow, .starlight, .none, .paper, 0.55)

        case let id where id.hasPrefix("xy") || id == "g1" || id == "dc1":
            // XY international cards: diagonal bottom-right to top-left sheen.
            return foil(.artWindow, .sheen, .none, .paper, 0.48)

        case let id where id.hasPrefix("sm") || id == "sma":
            return foil(.artWindow, .waterWeb, .none, .paper, 0.52)

        case "cel25":
            return foil(.artWindow, .celebrationSheen, .none, .holo, 0.46)

        case let id where id.hasPrefix("swsh") || id == "pgo":
            return foil(.artWindow, .verticalLine, .none, .paper, 0.48)

        case "rsv10pt5", "zsv10pt5":
            // Black Bolt / White Flare intentionally revive B&W horizontal foil.
            // They retain the modern silver frame, which also catches the foil.
            return foil(.artAndBorder, .tinsel, .none, .silver, 0.50)

        case let id where id.hasPrefix("sv") || id.hasPrefix("me") || id == "cel30":
            // Scarlet & Violet and Mega Evolution standard holos use a restrained
            // horizontal mirage sheet. Their silver frame is foil-bearing too;
            // artWindow alone masked that reflection away.
            return foil(.artAndBorder, .mirage, .none, .silver, 0.46)

        default:
            // Base Set 2 through Call of Legends, including e-Card, EX, DP,
            // Platinum and HGSS, used the Cosmos family for standard holos.
            return foil(.artWindow, .cosmos, .none, .paper, 0.52)
        }
    }

    // MARK: Reverse / parallel sheets

    private static func reverseHolo(cardID: String, setID: String,
                                    rarity: String) -> FoilSpec {
        if matches(cardID: cardID, setID: setID, table: teamPlasmaReverseNumbers) {
            return foil(.outsideArt, .mirror, .none, .silver, 0.46)
        }
        if matches(cardID: cardID, setID: setID, table: ancientTraitReverseNumbers) {
            return foil(.traitBands, .mirror, .none, .silver, 0.46)
        }
        if matches(cardID: cardID, setID: setID, table: ancientFutureReverseNumbers) {
            return foil(.outsideArt, .mirror, .none, .silver, 0.46)
        }
        if matches(cardID: cardID, setID: setID, table: dualTypeReverseNumbers) {
            return foil(.outsideArt, .splitTypeSymbols, .none, .silver, 0.50)
        }

        let isRareParallel = rarity == "rare" || rarity.contains("holo")

        switch setID {
        case "base6":
            return foil(.outsideArt, .fireworks, .none, .silver, 0.56)

        case "ecard1", "ecard2", "ecard3", "ex1", "ex2", "ex3", "ex4":
            return foil(.outsideArt, .mirror, .none, .silver, 0.43)

        case "ex5":
            return foil(isRareParallel ? .artWindowAndMark : .artWindow,
                        isRareParallel ? .energyTypeStamp : .energySymbols,
                        .none, .silver, 0.54)
        case "ex6":
            return foil(isRareParallel ? .artWindowAndMark : .artWindow,
                        isRareParallel ? .energyPokeBallStamp : .energySymbols,
                        .none, .silver, 0.56)
        case "ex7":
            return foil(.artWindow, .energySetStamp, .none,
                        isRareParallel ? .gold : .silver, 0.57)
        case "ex8":
            return foil(.artWindow, .pinwheel, .none, .silver, 0.56)
        case "ex9":
            return foil(.artWindow, .pokeBallStars, .none, .silver, 0.56)
        case "ex10":
            return foil(.artBackground, .pokeBall3D, .none, .silver, 0.57)
        case "ex12":
            return foil(.artWindow, .cosmosStamp, .none, .silver, 0.52)
        case "ex15":
            return foil(.artWindow, .subjectStamp, .none, .silver, 0.52)
        case "ex11", "ex13", "ex14", "ex16":
            return foil(.artWindow, .stampedMirror, .none, .silver, 0.50)

        case let id where id.hasPrefix("dp") || id.hasPrefix("pl")
            || id.hasPrefix("hgss") || id == "col1" || id == "bw1":
            return foil(.outsideArt, .mirror, .none, .silver, 0.44)

        case "dc1", "xy12":
            return foil(.outsideArt, .mirror, .none, .silver, 0.45)

        case let id where (id.hasPrefix("bw") && id != "bw1")
            || (id.hasPrefix("xy") && id != "xy12") || id == "g1":
            return foil(.outsideArt, .typeSymbols, .none, .silver, 0.50)

        case let id where id.hasPrefix("sm") || id == "sma":
            return foil(.outsideArt, .sunMoonSymbols, .none, .silver, 0.52)

        case let id where id.hasPrefix("swsh") || id == "cel25" || id == "pgo":
            return foil(.outsideArt, .swordShieldTiles, .none, .silver, 0.50)

        case let id where id.hasPrefix("sv")
            || id == "rsv10pt5" || id == "zsv10pt5":
            return foil(.outsideArt, .scarletVioletTiles, .none, .silver, 0.52)

        case let id where id.hasPrefix("me"):
            // Mega Evolution removed the era-specific symbol tile and returned
            // to a clean mirror-like reverse background.
            return foil(.outsideArt, .mirror, .none, .silver, 0.45)

        default:
            return foil(.outsideArt, .reverse, .fineLines, .silver, 0.46)
        }
    }

    // MARK: Rule-box and premium sheets

    private static func fullArt(cardID: String, setID: String,
                                rarity: String,
                                visualKind: CardVisualKind?) -> FoilSpec {
        if cardID == "swsh12pt5-160"
            || (setID == "sm12" && numericCardNumber(cardID).map {
                (237...248).contains($0)
            } == true) {
            return foil(.fullCard, .satin, .fineLines, .silver, 0.48)
        }
        if setID.hasSuffix("tg") || setID.hasSuffix("gg") {
            if rarity.contains("vmax") {
                return foil(.fullCard, .vmaxRays, .none, .holo, 0.59)
            }
            if rarity.contains("vstar") {
                return foil(.fullCard, .vstarSheen, .none, .silver, 0.54)
            }
            // Yellow-border CHR/GG illustration cards use a smooth foil. Rule-
            // box V/VMAX/VSTAR and Supporter variants resolve through `etched`.
            return foil(.fullCard, .satin, .none, .silver, 0.48)
        }
        if rarity.contains("illustration") || rarity.contains("trainer gallery") {
            return foil(.fullCard, .satin, .none, .silver, 0.46)
        }
        if rarity == "double rare" {
            let texture: FoilTexture = visualKind?.isTera == true
                ? .scarletVioletEtched : .none
            let intensity = visualKind?.isTera == true ? 0.57 : 0.50
            let pattern: FoilPattern = visualKind?.isTera == true
                ? .teraSheen : .doubleRareSheen
            return foil(.fullCard, pattern, texture, .silver, intensity)
        }
        if rarity == "rare holo v" {
            return foil(.fullCard, .verticalLine, .none, .holo, 0.50)
        }
        if rarity == "rare holo gx" {
            return foil(.fullCard, .waterWeb, .none, .holo, 0.52)
        }
        if rarity == "rare holo ex" {
            let isModernSilver = setID.hasPrefix("sv") || setID.hasPrefix("me")
            let pattern: FoilPattern = isModernSilver
                ? (visualKind?.isTera == true ? .teraSheen : .doubleRareSheen)
                : .verticalLine
            let border: FoilBorder = isModernSilver ? .silver : .holo
            let texture: FoilTexture = visualKind?.isTera == true
                ? .scarletVioletEtched : .none
            return foil(.fullCard, pattern, texture, border,
                        visualKind?.isTera == true ? 0.57 : 0.52)
        }
        return foil(.fullCard, .spectrum, .fineLines, .silver, 0.52)
    }

    private static func etched(cardID: String, setID: String, rarity: String,
                               tier: CardTier,
                               visualKind: CardVisualKind?) -> FoilSpec {
        if tier == .futureUltra || rarity.contains("futuristic rare") {
            return foil(.fullCard, .futuristic, .none, .holo, 0.66)
        }
        if setID.hasSuffix("tg") || setID.hasSuffix("gg") {
            if rarity.contains("vmax") {
                return foil(.fullCard, .vmaxRays, .none, .holo, 0.61)
            }
            if rarity.contains("vstar") {
                return foil(.fullCard, .vstarSheen, .none, .silver, 0.56)
            }
            return foil(.fullCard, .satin, .swordShieldEtched, .silver, 0.55)
        }
        if rarity.contains("vmax") {
            return foil(.fullCard, .vmaxRays, .none, .holo, 0.62)
        }
        if rarity.contains("vstar") {
            return foil(.fullCard, .vstarSheen, .none, .silver, 0.56)
        }
        if rarity.contains("special illustration") {
            // The dedicated pattern already contains the fine embossed ridges.
            // Adding the generic diagonal `etched` texture on top makes two
            // unrelated grids cross and no longer resembles the physical card.
            return foil(.fullCard, .specialIllustration, .none, .silver, 0.74)
        }
        if visualKind?.isTera == true && rarity.contains("ultra rare") {
            // Full-art Tera ex cards use the crystalline textured treatment as
            // well as Double Rare Tera cards. Without visual metadata these 34
            // bundled printings collapsed into the generic line foil.
            return foil(.fullCard, .teraSheen, .scarletVioletEtched, .silver, 0.62)
        }
        if ["bw1", "bw2", "bw3"].contains(setID) {
            // English BW full arts were still flat foil; raised, card-specific
            // texture arrived with Next Destinies (BW4).
            return foil(.fullCard, .tinsel, .none, .silver, 0.54)
        }
        if untexturedXYSecretIDs.contains(cardID) {
            // Early XY gold-border secret EX printings are glossy but flat.
            return foil(.fullCard, .sheen, .none, .gold, 0.55)
        }

        let isTrainer = visualKind?.supertype == .trainer
        let isEnergy = visualKind?.supertype == .energy
        // Full-art texture changed with the underlying era sheet. The embossed
        // flow remains a physical texture, but Pokémon, Trainer and Energy
        // sheets no longer collapse into one rainbow `line` material.
        switch setID {
        case let id where id.hasPrefix("bw"):
            return foil(.fullCard, isTrainer ? .satin : .tinsel,
                        .bwEtched, .silver, 0.56)
        case let id where id.hasPrefix("xy") || id == "g1" || id == "dc1":
            return foil(.fullCard, isTrainer ? .satin : .sheen,
                        .xyEtched, .silver, 0.57)
        case let id where id.hasPrefix("sm") || id == "sma":
            return foil(.fullCard, isTrainer ? .satin : .waterWeb,
                        .sunMoonEtched, .silver, 0.59)
        case let id where id.hasPrefix("swsh") || id == "pgo" || id == "cel25":
            let pattern: FoilPattern = isEnergy ? .typeSymbols
                : (isTrainer ? .satin : .verticalLine)
            return foil(.fullCard, pattern, .swordShieldEtched, .silver, 0.59)
        case let id where id.hasPrefix("sv") || id.hasPrefix("rsv")
            || id.hasPrefix("zsv"):
            // `line` already draws its own fixed contour field. A second
            // generic etched texture was the visible double-grid regression.
            if isEnergy {
                return foil(.fullCard, .typeSymbols, .scarletVioletEtched,
                            .silver, 0.60)
            }
            return foil(.fullCard, isTrainer ? .satin : .line,
                        isTrainer ? .scarletVioletEtched : .none, .silver, 0.60)
        case let id where id.hasPrefix("me"):
            let pattern: FoilPattern = isEnergy ? .typeSymbols
                : (isTrainer ? .satin : .mirage)
            // Mega Evolution continues the current fine-etch carrier. Its
            // card-specific background/subject geometry is the visible change;
            // no source supports inventing a new universal Mega emboss sheet.
            return foil(.fullCard, pattern, .scarletVioletEtched, .silver, 0.60)
        default:
            return foil(.fullCard, .line, .none, .silver, 0.58)
        }
    }

    private static func shiny(cardID: String, setID: String,
                              rarity: String) -> FoilSpec {
        if setID == "neo3" {
            return foil(.artWindow, .cosmos, .none, .paper, 0.53)
        }
        if setID == "sm35" {
            // Shining Legends foils the Pokémon itself, not the artwork window.
            // The silhouette is estimated from this card's scan; it is not a
            // measured factory mask. Keep the ordinary yellow border unfoiled.
            return foil(.artSubject, .satin, .sunMoonEtched, .paper, 0.67)
        }
        if setID == "neo4" {
            return foil(.artSubject, .refractor, .none, .paper, 0.62)
        }
        if rarity.contains("shining") {
            return foil(.artWindow, .refractor, .none, .silver, 0.52)
        }
        if isRefractorGoldStar(cardID) {
            return foil(.artAndBorder, .refractor, .none, .gold, 0.56)
        }
        if rarity.contains("holo star") {
            return foil(.artAndBorder, .starSheen, .none, .gold, 0.54)
        }
        if setID.hasPrefix("bw") && rarity == "rare secret" {
            // B&W secret Shiny Pokémon use a raised sheet with gold trim, not
            // the silver-bordered Shiny Vault treatment of later eras.
            return foil(.artAndBorder, .starfield, .bwEtched, .gold, 0.55)
        }
        if setID == "sma" {
            // Hidden Fates Shiny Vault: subdued silver sparkles over a tactile
            // surface, while the printed frame remains the older yellow style.
            return foil(.artWindow, .starfield, .embossed, .paper, 0.52)
        }
        if setID == "swsh45sv" {
            // Shining Fates has brighter sparkles than Hidden Fates. Do not
            // substitute the unrelated full-card diagonal starSheen stripes
            // for the printed streaks around individual Pokémon.
            return foil(.artWindow, .starfield, .embossed, .paper, 0.57)
        }
        if setID == "sv4pt5" {
            // Paldean Fates brings a reflective silver frame and a finer
            // textured carrier to its Shiny Rares.
            return foil(.artAndBorder, .starfield, .scarletVioletEtched,
                        .silver, 0.58)
        }
        return foil(.artAndBorder, .starfield, .fineLines, .silver, 0.55)
    }

    private static func shinyFullArt(setID: String, rarity: String,
                                     visualKind: CardVisualKind?) -> FoilSpec {
        if rarity.contains("vmax") {
            return foil(.fullCard, .shinyVMAX, .none, .holo, 0.63)
        }
        if setID.hasPrefix("sm") || setID == "sma" {
            return foil(.fullCard, .shinyGX, .none, .silver, 0.60)
        }
        if setID.hasPrefix("swsh") {
            return foil(.fullCard, .shinyV, .none, .holo, 0.61)
        }
        if setID.hasPrefix("sv") {
            return foil(.fullCard,
                        visualKind?.isTera == true ? .teraShinyEx : .shinyEx,
                        .none, .silver, visualKind?.isTera == true ? 0.64 : 0.60)
        }
        return foil(.fullCard, .shinyV, .none, .silver, 0.59)
    }

    private static func gold(setID: String, rarity: String,
                             visualKind: CardVisualKind?) -> FoilSpec {
        if rarity.contains("mega hyper") {
            // MUR is gold-etched, not a rainbow Mega Attack coating. The
            // dedicated pattern owns its micro-etch to avoid a second grid.
            return foil(.fullCard, .megaGold, .none, .gold, 0.62)
        }
        switch setID {
        case let id where id.hasPrefix("bw"):
            return foil(.fullCard, .bwGold, .none, .gold, 0.59)
        case let id where id.hasPrefix("xy") || id == "g1" || id == "dc1":
            return foil(.fullCard, .xyGold, .none, .gold, 0.59)
        case let id where id.hasPrefix("sm") || id == "sma":
            return foil(.fullCard, .sunMoonGold, .none, .gold, 0.60)
        case let id where id.hasPrefix("swsh") || id == "pgo" || id == "cel25":
            return foil(.fullCard, .swordShieldGold, .none, .gold, 0.61)
        case let id where id.hasPrefix("sv") || id.hasPrefix("rsv")
            || id.hasPrefix("zsv"):
            return foil(.fullCard,
                        visualKind?.isTera == true ? .teraGold : .scarletVioletGold,
                        .none, .gold, visualKind?.isTera == true ? 0.63 : 0.60)
        default:
            return foil(.fullCard, .gold, .etched, .gold, 0.58)
        }
    }

    private static func rainbow(setID: String) -> FoilSpec {
        if setID.hasPrefix("sm") || setID == "sma" {
            return foil(.fullCard, .rainbow, .sunMoonEtched, .silver, 0.54)
        }
        if setID.hasPrefix("swsh") || setID == "pgo" {
            return foil(.fullCard, .rainbow, .swordShieldEtched, .silver, 0.54)
        }
        return foil(.fullCard, .rainbow, .etched, .silver, 0.54)
    }

    private static func aceSpec(setID: String) -> FoilSpec {
        if setID.hasPrefix("bw") {
            return foil(.fullCard, .tinsel, .none, .paper, 0.56)
        }
        // Scarlet & Violet ACE SPEC cards carry a full-card holofoil treatment
        // (ComicBook/PokéBeach, Temporal Forces reveal); the art box is foiled too.
        return foil(.fullCard, .aceDiamond, .embossed, .magenta, 0.57)
    }

    private static func blackWhite(cardID: String) -> FoilSpec {
        if cardID == "rsv10pt5-173" {
            return foil(.fullCard, .whiteEtched, .none, .blackWhite, 0.60)
        }
        if cardID == "zsv10pt5-172" {
            return foil(.fullCard, .blackEtched, .none, .blackWhite, 0.60)
        }
        return foil(.fullCard, .monochrome, .etched, .blackWhite, 0.58)
    }

    private static func radiantCollection(cardID: String, setID: String) -> FoilSpec {
        if setID == "bw11" || setID == "bw11RC" {
            return foil(.fullCard, .starSheen, .none, .holo, 0.55)
        }
        // Generations RC is not XY's engraved EX full-art stock. The old
        // fineLines flag selected engraved relief even on its smooth foil.
        // See docs/reference/generations-rc-2026-09-28.md for evidence limits.
        if cardID == "g1-RC29" {
            return foil(.artWindow, .satin, .none, .paper, 0.50)
        }
        return foil(.fullCard, .satin, .none, .holo, 0.50)
    }

    private static func isAlphLithograph(_ cardID: String) -> Bool {
        cardID == "hgss1-ONE" || cardID == "hgss2-TWO"
            || cardID == "hgss3-THREE" || cardID == "hgss4-FOUR"
    }

    /// The current high-resolution assets for these printings already show
    /// their cracked-ice sheet. The renderer uses this same set to avoid
    /// generating a second, differently aligned shard lattice.
    static func hasBakedCrackedIceScan(_ cardID: String) -> Bool {
        if cardID.hasPrefix("pl2-RT") { return true }
        return [
            "ex5-97", "ex5-98", "ex5-99",
            "ex6-114", "ex6-115", "ex6-116",
        ].contains(cardID)
    }

    static func isRefractorGoldStar(_ cardID: String) -> Bool {
        cardID == "ex13-102" || cardID == "ex15-100" || cardID == "ex15-101"
    }

    private static func numericCardNumber(_ cardID: String) -> Int? {
        guard let separator = cardID.lastIndex(of: "-") else { return nil }
        return Int(cardID[cardID.index(after: separator)...])
    }

    private static func matches(cardID: String, setID: String,
                                table: [String: Set<Int>]) -> Bool {
        guard let number = numericCardNumber(cardID) else { return false }
        return table[setID]?.contains(number) == true
    }

    private static let untexturedXYSecretIDs: Set<String> = [
        "xy2-107", "xy2-108", "xy2-109",
        "xy3-112", "xy3-113",
        "xy4-120", "xy4-121", "xy4-122",
    ]

    private static let teamPlasmaReverseNumbers: [String: Set<Int>] = [
        "bw8": [3, 13, 17, 33, 39, 41, 46, 49, 55, 58, 62, 66, 67, 70,
                84, 86, 87, 90, 91, 92, 94, 101, 112, 113, 114, 118, 119,
                123, 124, 125, 127],
        "bw9": [11, 12, 16, 20, 23, 26, 29, 30, 31, 34, 46, 48, 49, 52,
                56, 57, 64, 66, 67, 70, 73, 74, 78, 79, 88, 100, 101, 102,
                104, 105, 106],
        "bw10": [2, 8, 13, 19, 22, 23, 24, 33, 61, 74, 76, 77, 86, 91],
    ]

    private static let ancientTraitReverseNumbers: [String: Set<Int>] = [
        "xy5": [9, 24, 26, 36, 37, 41, 52, 60, 64, 69, 71, 77, 81, 97,
                104, 108, 117, 121],
        "xy6": [8, 17, 28, 32, 46, 52, 72, 74, 81],
        "xy7": [11, 15, 18, 21, 32, 35, 50, 67],
    ]

    private static let ancientFutureReverseNumbers: [String: Set<Int>] = [
        "sv4": [28, 56, 86, 107, 123, 158, 159, 163, 164, 170, 171, 180],
        "sv5": [61, 62, 77, 78, 79, 80, 96, 97, 98, 109, 118, 119, 121,
                139, 140, 145, 147, 149],
        "sv6": [19, 62, 63, 118],
        "sv6pt5": [9, 26],
        "sv7": [71, 111],
        "sv8": [38, 55, 69, 96, 116, 132],
        "sv8pt5": [42, 43, 46, 55, 65, 104, 106, 107, 120, 121, 130],
    ]

    private static let dualTypeReverseNumbers: [String: Set<Int>] = [
        "xy11": [11, 15, 42, 64, 77],
    ]

    private static func foil(
        _ coverage: FoilCoverage,
        _ pattern: FoilPattern,
        _ texture: FoilTexture,
        _ border: FoilBorder,
        _ intensity: Double
    ) -> FoilSpec {
        FoilSpec(coverage: coverage, pattern: pattern, texture: texture,
                 border: border, intensity: intensity)
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
}
