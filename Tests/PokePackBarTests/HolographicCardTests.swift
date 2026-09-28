import XCTest
@testable import PokePackBar

@MainActor
final class HoloVisualDiagnosticsTests: XCTestCase {
    func testActualSizeFlatCardRequestKeepsExplicitPrinting() {
        let request = HoloVisualDiagnostics.request(from: [
            "PokePackBar", "--render-holo-preview", "ex6-1", "/tmp/foil-audit",
            "reverseHolo", "--compact", "--actual-size", "--flat-card",
        ])

        XCTAssertEqual(request?.cardID, "ex6-1")
        XCTAssertEqual(request?.finish, .reverseHolo)
        XCTAssertEqual(request?.compact, true)
        XCTAssertEqual(request?.actualSize, true)
        XCTAssertEqual(request?.flatCard, true)
        XCTAssertEqual(request?.sweep, false)
    }

    func testSweepRequestKeepsActualPrintingAndSize() {
        let request = HoloVisualDiagnostics.request(from: [
            "PokePackBar", "--render-holo-preview", "sv8pt5-1", "/tmp/foil-audit",
            "masterBall", "--actual-size", "--flat-card", "--sweep",
        ])
        XCTAssertEqual(request?.finish, .masterBall)
        XCTAssertEqual(request?.actualSize, true)
        XCTAssertEqual(request?.flatCard, true)
        XCTAssertEqual(request?.sweep, true)
    }
}

final class FoilReliefMaterialTests: XCTestCase {
    func testPrintingKeepsItsOwnReliefFamily() {
        XCTAssertEqual(FoilReliefMaterial(pattern: .megaGold), .gold(.megaGold))
        XCTAssertEqual(FoilReliefMaterial(pattern: .teraGold), .gold(.teraGold))
        XCTAssertEqual(FoilReliefMaterial(pattern: .specialIllustration), .illustration)
        XCTAssertEqual(FoilReliefMaterial(pattern: .whiteEtched), .white)
        XCTAssertEqual(FoilReliefMaterial(pattern: .blackEtched), .black)
        XCTAssertNil(FoilReliefMaterial(pattern: .cosmos))
        XCTAssertNil(FoilReliefMaterial(pattern: .masterBall))
    }

    func testSmoothFoilAndEngravedPrintDoNotShareTheSameSurface() {
        XCTAssertEqual(FoilReliefMaterial(pattern: .verticalLine), .linear(.verticalLine))
        XCTAssertEqual(FoilReliefMaterial(pattern: .verticalLine, texture: .bwEtched),
                       .engraved(.verticalLine, .bwEtched))
        XCTAssertGreaterThan(FoilReliefMaterial.linear(.mirage).reflectionExponent,
                             FoilReliefMaterial.illustration.reflectionExponent)
    }
}

final class CardFinishResolverTests: XCTestCase {

    func testPreScarletVioletPlainRareIsNotFoil() {
        let resolved = CardFinishResolver.resolve(
            setID: "xy8", originalRarity: "Rare", tier: .rare)

        XCTAssertEqual(resolved.finish, .normal)
        XCTAssertFalse(resolved.spec.isFoil)
        XCTAssertEqual(resolved.spec.coverage, .none)
        XCTAssertEqual(HoloProfile.of(resolved.spec).foil, 0)
        XCTAssertEqual(HoloProfile.of(resolved.spec).sparkle, 0)
    }

    func testScarletVioletAndMegaPlainRaresUseBoosterHoloSheets() {
        let scarletViolet = CardFinishResolver.resolve(
            cardID: "sv4-1", setID: "sv4", originalRarity: "Rare", tier: .rare)
        XCTAssertEqual(scarletViolet.finish, .holo)
        XCTAssertEqual(scarletViolet.spec.pattern, .mirage)
        XCTAssertEqual(scarletViolet.spec.coverage, .artAndBorder)
        XCTAssertEqual(scarletViolet.spec.border, .silver)

        let mega = CardFinishResolver.resolve(
            cardID: "me1-1", setID: "me1", originalRarity: "Rare", tier: .rare)
        XCTAssertEqual(mega.finish, .holo)
        XCTAssertEqual(mega.spec.pattern, .mirage)
        XCTAssertEqual(mega.spec.coverage, .artAndBorder)
    }

    func testMetadataFreeRareIsNotFoil() {
        let resolved = CardFinishResolver.resolve(
            setID: "unknown", originalRarity: nil, tier: .rare)
        XCTAssertEqual(resolved.finish, .normal)
    }

    func testExplicitPrintingAlwaysWinsOverRarity() {
        let resolved = CardFinishResolver.resolve(
            setID: "sv8pt5", originalRarity: "Hyper Rare", tier: .ultraRare,
            explicitFinish: .masterBall)

        XCTAssertEqual(resolved.finish, .masterBall)
        XCTAssertEqual(resolved.spec.pattern, .masterBall)
        XCTAssertEqual(resolved.spec.coverage, .outsideArt)
    }

    func testResolverMapsSourceLabelsToPhysicalFinishes() {
        struct Example {
            let setID: String
            let rarity: String
            let tier: CardTier
            let finish: CardFinish
            let coverage: FoilCoverage
            let pattern: FoilPattern
            let texture: FoilTexture
        }

        let examples = [
            Example(setID: "base1", rarity: "Rare Holo", tier: .doubleRare,
                    finish: .holo, coverage: .artWindow, pattern: .starlight, texture: .none),
            Example(setID: "sv3pt5", rarity: "Reverse Holo", tier: .rare,
                    finish: .reverseHolo, coverage: .outsideArt,
                    pattern: .scarletVioletTiles, texture: .none),
            Example(setID: "sv4", rarity: "Illustration Rare", tier: .artRare,
                    finish: .fullArt, coverage: .fullCard, pattern: .satin,
                    texture: .none),
            Example(setID: "sv4", rarity: "Special Illustration Rare",
                    tier: .specialArtRare, finish: .etched, coverage: .fullCard,
                    pattern: .specialIllustration, texture: .none),
            Example(setID: "swsh11", rarity: "Radiant Rare", tier: .radiant,
                    finish: .radiant, coverage: .fullCard, pattern: .crosshatch,
                    texture: .none),
            Example(setID: "swsh4", rarity: "Amazing Rare", tier: .amazing,
                    finish: .amazingRare, coverage: .fullCard, pattern: .rainbowSplash,
                    texture: .none),
            Example(setID: "sm12", rarity: "Rare Rainbow", tier: .hyperRare,
                    finish: .rainbow, coverage: .fullCard, pattern: .rainbow,
                    texture: .sunMoonEtched),
            Example(setID: "pgo", rarity: "Rare Rainbow", tier: .hyperRare,
                    finish: .rainbow, coverage: .fullCard, pattern: .rainbow,
                    texture: .swordShieldEtched),
            Example(setID: "sv4", rarity: "Hyper Rare", tier: .ultraRare,
                    finish: .gold, coverage: .fullCard, pattern: .scarletVioletGold,
                    texture: .none),
            Example(setID: "me1", rarity: "Mega Hyper Rare", tier: .megaUltraRare,
                    finish: .gold, coverage: .fullCard, pattern: .megaGold,
                    texture: .none),
            Example(setID: "me3", rarity: "Mega Attack Rare", tier: .megaAttack,
                    finish: .megaAttack, coverage: .subjectAndAttack, pattern: .comicBurst,
                    texture: .none),
            Example(setID: "sv4pt5", rarity: "Shiny Rare", tier: .shiny,
                    finish: .shiny, coverage: .artAndBorder, pattern: .starfield,
                    texture: .scarletVioletEtched),
            Example(setID: "swsh45", rarity: "Rare Holo VMAX", tier: .shinyUltra,
                    finish: .shinyFullArt, coverage: .fullCard, pattern: .shinyVMAX,
                    texture: .none),
            Example(setID: "swsh9", rarity: "Trainer Gallery Rare Holo",
                    tier: .characterRare, finish: .fullArt, coverage: .fullCard,
                    pattern: .satin, texture: .none),
            Example(setID: "sv6", rarity: "ACE SPEC Rare", tier: .aceSpec,
                    finish: .aceSpec, coverage: .outsideArt, pattern: .aceDiamond,
                    texture: .embossed),
            Example(setID: "sv8pt5", rarity: "Poké Ball Reverse", tier: .common,
                    finish: .pokeBall, coverage: .outsideArt, pattern: .pokeBall,
                    texture: .embossed),
            Example(setID: "sv8pt5", rarity: "Master Ball Reverse", tier: .common,
                    finish: .masterBall, coverage: .outsideArt, pattern: .masterBall,
                    texture: .embossed),
            Example(setID: "cel25", rarity: "Classic Collection", tier: .doubleRare,
                    finish: .celebrationsClassic, coverage: .fullCard, pattern: .confetti,
                    texture: .none),
            Example(setID: "swsh1", rarity: "Rare Holo V", tier: .doubleRare,
                    finish: .fullArt, coverage: .fullCard, pattern: .verticalLine,
                    texture: .none),
            Example(setID: "swsh7", rarity: "Rare Holo VMAX", tier: .tripleRare,
                    finish: .etched, coverage: .fullCard, pattern: .vmaxRays,
                    texture: .none),
            Example(setID: "sv1", rarity: "Double Rare", tier: .doubleRare,
                    finish: .fullArt, coverage: .fullCard, pattern: .doubleRareSheen,
                    texture: .none),
            Example(setID: "xy8", rarity: "Rare BREAK", tier: .doubleRare,
                    finish: .breakFoil, coverage: .fullCard, pattern: .breakGrid,
                    texture: .fineLines),
        ]

        for example in examples {
            let resolved = CardFinishResolver.resolve(
                setID: example.setID, originalRarity: example.rarity, tier: example.tier)
            XCTAssertEqual(resolved.finish, example.finish, example.rarity)
            XCTAssertEqual(resolved.spec.coverage, example.coverage, example.rarity)
            XCTAssertEqual(resolved.spec.pattern, example.pattern, example.rarity)
            XCTAssertEqual(resolved.spec.texture, example.texture, example.rarity)
        }
    }

    func testCelebrationsBaseRareUsesHoloArtWindow() {
        let resolved = CardFinishResolver.resolve(
            setID: "cel25", originalRarity: "Rare", tier: .rare)
        XCTAssertEqual(resolved.finish, .holo)
        XCTAssertEqual(resolved.spec.coverage, .artWindow)
        XCTAssertEqual(resolved.spec.pattern, .celebrationSheen)
    }

    @MainActor
    func testGenerationsRadiantCollectionHasNoEngravedRelief() throws {
        let index = try XCTUnwrap(CardIndex.shared)
        try FoilOpticsAudit.verifyRadiantCollection(index: index)
    }

    func testStandardHoloSheetsFollowReleaseEra() {
        struct Example {
            let cardID: String
            let setID: String
            let pattern: FoilPattern
        }
        let examples = [
            Example(cardID: "base1-1", setID: "base1", pattern: .starlight),
            Example(cardID: "base4-1", setID: "base4", pattern: .cosmos),
            Example(cardID: "bw7-1", setID: "bw7", pattern: .tinsel),
            Example(cardID: "xy8-1", setID: "xy8", pattern: .sheen),
            Example(cardID: "xy12-1", setID: "xy12", pattern: .starlight),
            Example(cardID: "sm7-1", setID: "sm7", pattern: .waterWeb),
            Example(cardID: "swsh9-1", setID: "swsh9", pattern: .verticalLine),
            Example(cardID: "sv4-1", setID: "sv4", pattern: .mirage),
            Example(cardID: "me1-1", setID: "me1", pattern: .mirage),
            Example(cardID: "rsv10pt5-1", setID: "rsv10pt5", pattern: .tinsel),
        ]

        for example in examples {
            let resolved = CardFinishResolver.resolve(
                cardID: example.cardID, setID: example.setID,
                originalRarity: "Rare Holo", tier: .doubleRare,
                explicitFinish: .holo)
            XCTAssertEqual(resolved.spec.pattern, example.pattern, example.cardID)
        }
    }

    func testModernSilverHoloFrameSharesFoilWithArtwork() {
        for cardID in ["sv4-1", "rsv10pt5-1", "zsv10pt5-1", "me1-1"] {
            let setID = String(cardID.split(separator: "-", maxSplits: 1)[0])
            let resolved = CardFinishResolver.resolve(
                cardID: cardID, setID: setID,
                originalRarity: "Rare Holo", tier: .doubleRare,
                explicitFinish: .holo)
            XCTAssertEqual(resolved.spec.coverage, .artAndBorder, cardID)
            XCTAssertEqual(resolved.spec.border, .silver, cardID)
        }

        let earlierYellowFrame = CardFinishResolver.resolve(
            cardID: "swsh9-1", setID: "swsh9",
            originalRarity: "Rare Holo", tier: .doubleRare,
            explicitFinish: .holo)
        XCTAssertEqual(earlierYellowFrame.spec.coverage, .artWindow)
        XCTAssertEqual(earlierYellowFrame.spec.border, .paper)
    }

    func testReverseSheetsFollowSetSpecificMotifs() {
        struct Example {
            let cardID: String
            let setID: String
            let coverage: FoilCoverage
            let pattern: FoilPattern
        }
        let examples = [
            Example(cardID: "base6-1", setID: "base6", coverage: .outsideArt,
                    pattern: .fireworks),
            Example(cardID: "ecard2-1", setID: "ecard2", coverage: .outsideArt,
                    pattern: .mirror),
            Example(cardID: "ex5-1", setID: "ex5", coverage: .artWindowAndMark,
                    pattern: .energyTypeStamp),
            Example(cardID: "ex6-1", setID: "ex6", coverage: .artWindowAndMark,
                    pattern: .energyPokeBallStamp),
            Example(cardID: "ex7-1", setID: "ex7", coverage: .artWindow,
                    pattern: .energySetStamp),
            Example(cardID: "ex8-1", setID: "ex8", coverage: .artWindow,
                    pattern: .pinwheel),
            Example(cardID: "ex9-1", setID: "ex9", coverage: .artWindow,
                    pattern: .pokeBallStars),
            Example(cardID: "ex10-1", setID: "ex10", coverage: .artBackground,
                    pattern: .pokeBall3D),
            Example(cardID: "ex12-1", setID: "ex12", coverage: .artWindow,
                    pattern: .cosmosStamp),
            Example(cardID: "ex13-1", setID: "ex13", coverage: .artWindow,
                    pattern: .stampedMirror),
            Example(cardID: "ex15-1", setID: "ex15", coverage: .artWindow,
                    pattern: .subjectStamp),
            Example(cardID: "dp3-1", setID: "dp3", coverage: .outsideArt,
                    pattern: .mirror),
            Example(cardID: "bw6-1", setID: "bw6", coverage: .outsideArt,
                    pattern: .typeSymbols),
            Example(cardID: "bw8-3", setID: "bw8", coverage: .outsideArt,
                    pattern: .mirror),
            Example(cardID: "xy5-9", setID: "xy5", coverage: .traitBands,
                    pattern: .mirror),
            Example(cardID: "xy11-11", setID: "xy11", coverage: .outsideArt,
                    pattern: .splitTypeSymbols),
            Example(cardID: "xy12-1", setID: "xy12", coverage: .outsideArt,
                    pattern: .mirror),
            Example(cardID: "sm8-1", setID: "sm8", coverage: .outsideArt,
                    pattern: .sunMoonSymbols),
            Example(cardID: "swsh9-1", setID: "swsh9", coverage: .outsideArt,
                    pattern: .swordShieldTiles),
            Example(cardID: "sv4-1", setID: "sv4", coverage: .outsideArt,
                    pattern: .scarletVioletTiles),
            Example(cardID: "sv4-28", setID: "sv4", coverage: .outsideArt,
                    pattern: .mirror),
            Example(cardID: "me1-1", setID: "me1", coverage: .outsideArt,
                    pattern: .mirror),
        ]

        for example in examples {
            let resolved = CardFinishResolver.resolve(
                cardID: example.cardID, setID: example.setID,
                originalRarity: "Reverse Holo", tier: .rare,
                explicitFinish: .reverseHolo)
            XCTAssertEqual(resolved.spec.coverage, example.coverage, example.cardID)
            XCTAssertEqual(resolved.spec.pattern, example.pattern, example.cardID)
        }

        let teamRocketRare = CardFinishResolver.resolve(
            cardID: "ex7-21", setID: "ex7", originalRarity: "Rare Holo",
            tier: .doubleRare, explicitFinish: .reverseHolo)
        XCTAssertEqual(teamRocketRare.spec.pattern, .energySetStamp)
        XCTAssertEqual(teamRocketRare.spec.border, .gold)
    }

    func testFullArtEtchingFollowsEraAndCardFrame() throws {
        struct Example {
            let cardID: String
            let setID: String
            let compactVisualKind: String
            let pattern: FoilPattern
            let texture: FoilTexture
            var border: FoilBorder = .silver
        }

        let examples = [
            Example(cardID: "bw1-113", setID: "bw1", compactVisualKind: "pR",
                    pattern: .tinsel, texture: .none),
            Example(cardID: "bw4-99", setID: "bw4", compactVisualKind: "pP",
                    pattern: .tinsel, texture: .bwEtched),
            Example(cardID: "bw4-100", setID: "bw4", compactVisualKind: "t",
                    pattern: .satin, texture: .bwEtched),
            Example(cardID: "xy2-107", setID: "xy2", compactVisualKind: "pR",
                    pattern: .sheen, texture: .none, border: .gold),
            Example(cardID: "xy5-150", setID: "xy5", compactVisualKind: "pW",
                    pattern: .sheen, texture: .xyEtched),
            Example(cardID: "sm1-138", setID: "sm1", compactVisualKind: "pG",
                    pattern: .waterWeb, texture: .sunMoonEtched),
            Example(cardID: "sm1-147", setID: "sm1", compactVisualKind: "t",
                    pattern: .satin, texture: .sunMoonEtched),
            Example(cardID: "swsh1-200", setID: "swsh1", compactVisualKind: "t",
                    pattern: .satin, texture: .swordShieldEtched),
            Example(cardID: "swsh12pt5-152", setID: "swsh12pt5",
                    compactVisualKind: "eP", pattern: .typeSymbols,
                    texture: .swordShieldEtched),
            Example(cardID: "sv1-223", setID: "sv1", compactVisualKind: "pR",
                    pattern: .line, texture: .none),
            Example(cardID: "sv1-239", setID: "sv1", compactVisualKind: "t",
                    pattern: .satin, texture: .scarletVioletEtched),
            Example(cardID: "me1-155", setID: "me1", compactVisualKind: "pG",
                    pattern: .mirage, texture: .scarletVioletEtched),
        ]

        for example in examples {
            let visualKind = try XCTUnwrap(CardVisualKind(
                compactCode: example.compactVisualKind))
            let resolved = CardFinishResolver.resolve(
                cardID: example.cardID, setID: example.setID,
                originalRarity: "Ultra Rare", tier: .superRare,
                visualKind: visualKind, explicitFinish: .etched)
            XCTAssertEqual(resolved.spec.pattern, example.pattern, example.cardID)
            XCTAssertEqual(resolved.spec.texture, example.texture, example.cardID)
            XCTAssertEqual(resolved.spec.border, example.border, example.cardID)
        }
    }

    func testGoldSheetsRemainEraSpecificWithoutGenericDoubleEtching() {
        let examples: [(String, String, FoilPattern)] = [
            ("bw5-111", "bw5", .bwGold),
            ("xy5-161", "xy5", .xyGold),
            ("sm1-158", "sm1", .sunMoonGold),
            ("swsh1-211", "swsh1", .swordShieldGold),
            ("sv1-253", "sv1", .scarletVioletGold),
        ]

        for (cardID, setID, pattern) in examples {
            let resolved = CardFinishResolver.resolve(
                cardID: cardID, setID: setID, originalRarity: "Hyper Rare",
                tier: .ultraRare, explicitFinish: .gold)
            XCTAssertEqual(resolved.spec.pattern, pattern, cardID)
            XCTAssertEqual(resolved.spec.texture, .none, cardID)
            XCTAssertEqual(resolved.spec.border, .gold, cardID)
        }
    }

    func testShinyFullArtSheetsFollowGXVSAndExGenerations() {
        let examples: [(String, String, String, FoilPattern)] = [
            ("sma-SV46", "sm115", "Rare Shiny GX", .shinyGX),
            ("swsh45sv-SV105", "swsh45", "Shiny Ultra Rare", .shinyV),
            ("sv4pt5-213", "sv4pt5", "Shiny Ultra Rare", .shinyEx),
        ]

        for (cardID, setID, rarity, pattern) in examples {
            let resolved = CardFinishResolver.resolve(
                cardID: cardID, setID: setID, originalRarity: rarity,
                tier: .shinyUltra, explicitFinish: .shinyFullArt)
            XCTAssertEqual(resolved.spec.pattern, pattern, cardID)
            XCTAssertEqual(resolved.spec.texture, .none, cardID)
        }
    }

    func testBundledBabyShinyFamiliesDoNotShareOneEraMaterial() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        struct Example {
            let cardID: String
            let sourceSetID: String
            let count: Int
            let pattern: FoilPattern
            let texture: FoilTexture
            let border: FoilBorder
        }
        let examples = [
            Example(cardID: "bw1-115", sourceSetID: "bw", count: 24,
                    pattern: .starfield, texture: .bwEtched, border: .gold),
            Example(cardID: "sma-SV1", sourceSetID: "sma", count: 45,
                    pattern: .starfield, texture: .embossed, border: .paper),
            Example(cardID: "swsh45sv-SV001", sourceSetID: "swsh45sv", count: 104,
                    pattern: .starfield, texture: .embossed, border: .paper),
            Example(cardID: "sv4pt5-100", sourceSetID: "sv4pt5", count: 120,
                    pattern: .starfield, texture: .scarletVioletEtched, border: .silver),
        ]

        for example in examples {
            let card = try XCTUnwrap(index.card(example.cardID), example.cardID)
            let resolved = CardFinishResolver.resolve(
                cardID: card.id, setID: card.setID,
                originalRarity: card.rarity, tier: card.tier,
                visualKind: card.visualKind)
            XCTAssertEqual(resolved.finish, .shiny, example.cardID)
            XCTAssertEqual(resolved.spec.coverage,
                           example.border == .paper ? .artWindow : .artAndBorder,
                           example.cardID)
            XCTAssertEqual(resolved.spec.pattern, example.pattern, example.cardID)
            XCTAssertEqual(resolved.spec.texture, example.texture, example.cardID)
            XCTAssertEqual(resolved.spec.border, example.border, example.cardID)

            let matchingCards = index.cards.filter { candidate in
                guard candidate.id.hasPrefix(example.sourceSetID) else { return false }
                return CardFinishResolver.resolve(
                    cardID: candidate.id, setID: candidate.setID,
                    originalRarity: candidate.rarity, tier: candidate.tier,
                    visualKind: candidate.visualKind).finish == .shiny
            }
            XCTAssertEqual(matchingCards.count, example.count, example.sourceSetID)
        }

        let hiddenFates = try XCTUnwrap(index.card("sma-SV1"))
        let shiningFates = try XCTUnwrap(index.card("swsh45sv-SV001"))
        let hiddenSpec = CardFinishResolver.resolve(
            cardID: hiddenFates.id, setID: hiddenFates.setID,
            originalRarity: hiddenFates.rarity, tier: hiddenFates.tier).spec
        let shiningSpec = CardFinishResolver.resolve(
            cardID: shiningFates.id, setID: shiningFates.setID,
            originalRarity: shiningFates.rarity, tier: shiningFates.tier).spec
        XCTAssertGreaterThan(shiningSpec.intensity, hiddenSpec.intensity)
    }

    func testTeraGoldAndTeraShinyKeepTheirCrystalGeometry() throws {
        let tera = try XCTUnwrap(CardVisualKind(compactCode: "pG!"))
        let teraGold = CardFinishResolver.resolve(
            cardID: "sv6-221", setID: "sv6", originalRarity: "Hyper Rare",
            tier: .ultraRare, visualKind: tera, explicitFinish: .gold)
        let teraShiny = CardFinishResolver.resolve(
            cardID: "sv4pt5-212", setID: "sv4pt5",
            originalRarity: "Shiny Ultra Rare", tier: .shinyUltra,
            visualKind: tera, explicitFinish: .shinyFullArt)

        XCTAssertEqual(teraGold.spec.pattern, .teraGold)
        XCTAssertEqual(teraGold.spec.texture, .none)
        XCTAssertEqual(teraShiny.spec.pattern, .teraShinyEx)
        XCTAssertEqual(teraShiny.spec.texture, .none)
    }

    func testRadiantUsesPrintedBorderAndFixedCrosshatchWithoutLooseSparkles() {
        let resolved = CardFinishResolver.resolve(
            cardID: "swsh10-46", setID: "swsh10",
            originalRarity: "Radiant Rare", tier: .radiant)

        XCTAssertEqual(resolved.spec.pattern, .crosshatch)
        XCTAssertEqual(resolved.spec.border, .paper)
        XCTAssertEqual(resolved.spec.texture, .none)
        XCTAssertEqual(HoloProfile.of(resolved.spec).sparkle, 0)
    }

    func testVintageAndSecretExceptionsDoNotCollapseToGenericGold() {
        let darkRaichu = CardFinishResolver.resolve(
            cardID: "base5-83", setID: "base5",
            originalRarity: "Rare Secret", tier: .ultraRare)
        XCTAssertEqual(darkRaichu.finish, .holo)
        XCTAssertEqual(darkRaichu.spec.pattern, .cosmos)

        let alph = CardFinishResolver.resolve(
            cardID: "hgss1-ONE", setID: "hgss1",
            originalRarity: "Rare Secret", tier: .ultraRare)
        XCTAssertEqual(alph.finish, .holo)
        XCTAssertEqual(alph.spec.coverage, .stoneSurface)
        XCTAssertEqual(alph.spec.pattern, .stone)

        let crackedIce = CardFinishResolver.resolve(
            cardID: "ex5-97", setID: "ex5",
            originalRarity: "Rare Holo EX", tier: .doubleRare)
        XCTAssertEqual(crackedIce.finish, .holo)
        XCTAssertEqual(crackedIce.spec.pattern, .crackedIce)

        let cosmicCharacter = CardFinishResolver.resolve(
            cardID: "sm12-241", setID: "sm12",
            originalRarity: "Rare Secret", tier: .ultraRare)
        XCTAssertEqual(cosmicCharacter.finish, .fullArt)
        XCTAssertEqual(cosmicCharacter.spec.pattern, .satin)

        let evolutionsNovelty = CardFinishResolver.resolve(
            cardID: "xy12-110", setID: "xy12",
            originalRarity: "Rare Secret", tier: .ultraRare)
        XCTAssertEqual(evolutionsNovelty.finish, .normal)
    }

    func testSubsetSourceIDOverridesParentMaterial() {
        let trainerGalleryVMAX = CardFinishResolver.resolve(
            cardID: "swsh9tg-TG15", setID: "swsh9",
            originalRarity: "Rare Holo VMAX", tier: .characterRare)
        XCTAssertEqual(trainerGalleryVMAX.finish, .etched)
        XCTAssertEqual(trainerGalleryVMAX.spec.pattern, .vmaxRays)
        XCTAssertEqual(trainerGalleryVMAX.spec.texture, .none)
    }

    func testBundledMegaHyperRaresUseGoldInsteadOfMegaAttackRainbow() throws {
        let index = try XCTUnwrap(CardIndex.loadBundled())
        for cardID in ["me1-187", "me1-188", "me2-130"] {
            let card = try XCTUnwrap(index.card(cardID), cardID)
            let resolved = CardFinishResolver.resolve(
                cardID: card.id,
                setID: card.setID,
                originalRarity: card.rarity,
                tier: card.tier
            )
            XCTAssertEqual(resolved.finish, .gold, cardID)
            XCTAssertEqual(resolved.spec.pattern, .megaGold, cardID)
            XCTAssertEqual(resolved.spec.border, .gold, cardID)
        }
    }

    func testModernDoubleRareUsesTeraSpecificMaterialOnlyWhenMetadataSaysTera() {
        let standard = CardFinishResolver.resolve(
            cardID: "sv1-123", setID: "sv1", originalRarity: "Double Rare",
            tier: .doubleRare, visualKind: CardVisualKind(compactCode: "pR"))
        XCTAssertEqual(standard.spec.pattern, .doubleRareSheen)
        XCTAssertEqual(standard.spec.texture, .none)

        let tera = CardFinishResolver.resolve(
            cardID: "sv1-32", setID: "sv1", originalRarity: "Double Rare",
            tier: .doubleRare, visualKind: CardVisualKind(compactCode: "pD!"))
        XCTAssertEqual(tera.spec.pattern, .teraSheen)
        XCTAssertEqual(tera.spec.texture, .scarletVioletEtched)
        XCTAssertGreaterThan(tera.spec.intensity, standard.spec.intensity)
    }

    func testTeraUltraRareDoesNotCollapseIntoGenericLineFoil() {
        let tera = CardFinishResolver.resolve(
            cardID: "sv1-224", setID: "sv1", originalRarity: "Ultra Rare",
            tier: .superRare, visualKind: CardVisualKind(compactCode: "pR!"))

        XCTAssertEqual(tera.finish, .etched)
        XCTAssertEqual(tera.spec.pattern, .teraSheen)
        XCTAssertEqual(tera.spec.texture, .scarletVioletEtched)
    }

    func testBlackWhiteRarePolarityIsCardSpecific() {
        let reshiram = CardFinishResolver.resolve(
            cardID: "rsv10pt5-173", setID: "rsv10pt5",
            originalRarity: "Black White Rare", tier: .blackWhiteRare)
        let zekrom = CardFinishResolver.resolve(
            cardID: "zsv10pt5-172", setID: "zsv10pt5",
            originalRarity: "Black White Rare", tier: .blackWhiteRare)

        XCTAssertEqual(reshiram.spec.pattern, .whiteEtched)
        XCTAssertEqual(zekrom.spec.pattern, .blackEtched)
        XCTAssertEqual(reshiram.spec.texture, .none)
        XCTAssertEqual(zekrom.spec.texture, .none)
    }

    func testRadiantCollectionCoatingFollowsEachSetsPhysicalPrinting() {
        XCTAssertEqual(CardFinishResolver.resolve(
            cardID: "g1-RC1", setID: "g1", originalRarity: "Common", tier: .common
        ).finish, .normal, "Generations RC commons are non-foil")
        XCTAssertEqual(CardFinishResolver.resolve(
            cardID: "g1-RC10", setID: "g1", originalRarity: "Uncommon", tier: .uncommon
        ).finish, .radiantCollection)
        XCTAssertEqual(CardFinishResolver.resolve(
            cardID: "bw11-RC1", setID: "bw11", originalRarity: "Common", tier: .common
        ).finish, .radiantCollection)
    }

    func testRepresentativeFinishesHaveDistinctMaterialSpecs() {
        let finishes: [CardFinish] = [
            .normal, .holo, .reverseHolo, .etched, .radiant, .amazingRare,
            .rainbow, .gold, .shiny, .shinyFullArt, .aceSpec, .masterBall,
            .celebrationsClassic, .radiantCollection, .blackWhite, .megaAttack,
        ]

        for (index, finish) in finishes.enumerated() {
            for other in finishes.dropFirst(index + 1) {
                XCTAssertNotEqual(finish.foilSpec, other.foilSpec,
                                  "\(finish) and \(other) collapsed to one material")
            }
        }
    }

    func testSpecialIllustrationRareIsPatternForwardWithoutBroadGlare() {
        let illustrationRare = CardFinishResolver.resolve(
            cardID: "sv1-211", setID: "sv1",
            originalRarity: "Illustration Rare", tier: .artRare)
        let specialIllustrationRare = CardFinishResolver.resolve(
            cardID: "sv1-245", setID: "sv1",
            originalRarity: "Special Illustration Rare", tier: .specialArtRare)

        XCTAssertEqual(illustrationRare.spec.pattern, .satin)
        XCTAssertEqual(specialIllustrationRare.spec.pattern, .specialIllustration)
        XCTAssertEqual(specialIllustrationRare.spec.texture, .none)

        let illustrationProfile = HoloProfile.of(illustrationRare.spec)
        let specialProfile = HoloProfile.of(specialIllustrationRare.spec)
        XCTAssertGreaterThan(specialProfile.foil, illustrationProfile.foil + 0.15)
        XCTAssertLessThan(specialProfile.glare, illustrationProfile.glare)
        XCTAssertGreaterThanOrEqual(specialProfile.foil, specialProfile.glare * 8)
    }

    func testEveryFinishHasValidIntensityAndOnlyNormalIsNonFoil() {
        for finish in CardFinish.allCases {
            XCTAssertGreaterThanOrEqual(finish.foilSpec.intensity, 0, "\(finish)")
            XCTAssertLessThanOrEqual(finish.foilSpec.intensity, 1, "\(finish)")
            XCTAssertEqual(finish.foilSpec.isFoil, finish != .normal, "\(finish)")
        }
    }
}

final class CardVisualKindTests: XCTestCase {

    func testCompactMetadataDecodesPokemonTypesAndTeraFlag() throws {
        let dualType = try XCTUnwrap(CardVisualKind(compactCode: "pGD"))
        XCTAssertEqual(dualType.supertype, .pokemon)
        XCTAssertEqual(dualType.types, [.grass, .darkness])
        XCTAssertFalse(dualType.isTera)

        let tera = try XCTUnwrap(CardVisualKind(compactCode: "pD!"))
        XCTAssertEqual(tera.types, [.darkness])
        XCTAssertTrue(tera.isTera)
    }

    func testCompactMetadataDistinguishesTrainerAndEnergy() throws {
        let trainer = try XCTUnwrap(CardVisualKind(compactCode: "t"))
        XCTAssertEqual(trainer.supertype, .trainer)
        XCTAssertTrue(trainer.types.isEmpty)

        let energy = try XCTUnwrap(CardVisualKind(compactCode: "eP"))
        XCTAssertEqual(energy.supertype, .energy)
        XCTAssertEqual(energy.types, [.psychic])
    }

    func testMalformedCompactMetadataIsRejected() {
        XCTAssertNil(CardVisualKind(compactCode: ""))
        XCTAssertNil(CardVisualKind(compactCode: "p"))
        XCTAssertNil(CardVisualKind(compactCode: "tG"))
        XCTAssertNil(CardVisualKind(compactCode: "e!"))
        XCTAssertNil(CardVisualKind(compactCode: "pX"))
    }
}

final class CardPrintingKeyTests: XCTestCase {

    func testPrintingKeyRoundTripsStorageIdentity() {
        let original = CardPrintingKey(cardID: "sv8pt5-101", finish: .masterBall)
        XCTAssertEqual(CardPrintingKey(storageKey: original.storageKey), original)
        XCTAssertEqual(original.storageKey, "sv8pt5-101#masterBall")
        XCTAssertEqual(original.id, original.storageKey)
    }

    func testLegacyBareCardIDMigratesToNormal() {
        let migrated = CardPrintingKey(storageKey: "base1-4")
        XCTAssertEqual(migrated.cardID, "base1-4")
        XCTAssertEqual(migrated.finish, .normal)
    }

    func testUnknownFinishSuffixIsPreservedAsLegacyCardID() {
        let migrated = CardPrintingKey(storageKey: "future-1#unknownFinish")
        XCTAssertEqual(migrated.cardID, "future-1#unknownFinish")
        XCTAssertEqual(migrated.finish, .normal)
    }
}

final class HoloProfileTests: XCTestCase {

    func testEveryFinishCanRotateWithinPhysicalRange() {
        for finish in CardFinish.allCases {
            let tilt = HoloProfile.of(finish).tilt
            XCTAssertGreaterThanOrEqual(tilt, HoloProfile.minTilt, "\(finish)")
            XCTAssertLessThanOrEqual(tilt, HoloProfile.maxTilt, "\(finish)")
            XCTAssertLessThanOrEqual(tilt, 8, "\(finish) looks like a rigid board")
        }
    }

    func testNormalPaperHasNoFoilOrSparkle() {
        let normal = HoloProfile.of(.normal)
        XCTAssertEqual(normal.foil, 0)
        XCTAssertEqual(normal.sparkle, 0)
        XCTAssertGreaterThan(normal.specular, 0, "coated paper should still reflect light")
    }

    func testFinishNotRarityControlsFoil() {
        XCTAssertEqual(HoloProfile.of(CardTier.rare).foil, 0)
        XCTAssertGreaterThan(HoloProfile.of(CardFinish.reverseHolo).foil, 0)
    }

    func testOpticalChannelsKeepArtworkReadable() {
        for finish in CardFinish.allCases {
            let profile = HoloProfile.of(finish)
            XCTAssertLessThanOrEqual(profile.specular, 0.12, "\(finish)")
            XCTAssertLessThanOrEqual(profile.foil, 0.55, "\(finish)")
            XCTAssertLessThanOrEqual(profile.glare, 0.14, "\(finish)")
            XCTAssertLessThanOrEqual(profile.edge, 0.40, "\(finish)")
            if finish != .normal {
                XCTAssertGreaterThanOrEqual(profile.foil, profile.glare * 3,
                                            "\(finish) should read as pattern, not white glare")
            }
        }
    }

    func testCornerTiltNeverExceedsMaximum() {
        let corners = [TiltVector(nx: 1, ny: 1), TiltVector(nx: -1, ny: 1),
                       TiltVector(nx: 1, ny: -1), TiltVector(nx: -1, ny: -1)]
        for corner in corners {
            XCTAssertEqual(corner.magnitude, 1, accuracy: 0.0001)
            XCTAssertLessThanOrEqual(corner.magnitude * HoloProfile.maxTilt, 8)
        }
    }
}

final class HoloInteractionTests: XCTestCase {

    func testReducedMotionFreezesPointerTiltAndPositionDependentEffects() {
        let pointer = TiltVector(nx: 0.7, ny: -0.4)
        XCTAssertEqual(HoloInteraction.effectiveTilt(pointer: pointer, reduceMotion: true), .zero)
    }

    func testPointerTiltRemainsInteractiveOtherwise() {
        let pointer = TiltVector(nx: 0.7, ny: -0.4)
        XCTAssertEqual(HoloInteraction.effectiveTilt(pointer: pointer, reduceMotion: false), pointer)
    }
}

final class HoloOpticsTests: XCTestCase {

    private let tilt = HoloProfile.of(CardFinish.etched).tilt

    func testRestHighlightSitsTowardTheLight() {
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: tilt)
        XCTAssertLessThan(rest.x, 0.5)
        XCTAssertLessThan(rest.y, 0.5)
    }

    func testHighlightMovesAgainstThePointer() {
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: tilt)
        let right = HoloOptics.highlight(nx: 1, ny: 0, tilt: tilt)
        let down = HoloOptics.highlight(nx: 0, ny: 1, tilt: tilt)
        XCTAssertLessThan(right.x, rest.x)
        XCTAssertEqual(right.y, rest.y, accuracy: 0.0001)
        XCTAssertLessThan(down.y, rest.y)
        XCTAssertEqual(down.x, rest.x, accuracy: 0.0001)
    }

    func testHighlightTravelScalesWithTilt() {
        let gentle = HoloOptics.highlight(nx: 1, ny: 0, tilt: HoloProfile.minTilt)
        let steep = HoloOptics.highlight(nx: 1, ny: 0, tilt: HoloProfile.maxTilt)
        let rest = HoloOptics.highlight(nx: 0, ny: 0, tilt: HoloProfile.minTilt)
        XCTAssertGreaterThan(abs(steep.x - rest.x), abs(gentle.x - rest.x))
    }

    func testBandMovesAgainstThePointer() {
        let rest = HoloOptics.bandPosition(nx: 0, ny: 0, tilt: tilt)
        XCTAssertLessThan(HoloOptics.bandPosition(nx: 1, ny: 0, tilt: tilt), rest)
        XCTAssertGreaterThan(HoloOptics.bandPosition(nx: -1, ny: 0, tilt: tilt), rest)
    }

    func testLightFeaturesStayNearTheCardAtEveryAngle() {
        for nx in [-1.0, -0.5, 0, 0.5, 1.0] {
            for ny in [-1.0, -0.5, 0, 0.5, 1.0] {
                let band = HoloOptics.bandPosition(
                    nx: nx, ny: ny, tilt: HoloProfile.maxTilt)
                XCTAssertGreaterThan(band, 0.12)
                XCTAssertLessThan(band, 0.88)

                let highlight = HoloOptics.highlight(
                    nx: nx, ny: ny, tilt: HoloProfile.maxTilt)
                XCTAssertGreaterThan(highlight.x, -0.1)
                XCTAssertLessThan(highlight.x, 1.1)
                XCTAssertGreaterThan(highlight.y, -0.1)
                XCTAssertLessThan(highlight.y, 1.1)
            }
        }
    }
}

final class TiltVectorTests: XCTestCase {

    private let size = CGSize(width: 200, height: 279)

    func testCenterIsFlat() {
        let center = TiltVector(point: CGPoint(x: 100, y: 139.5), in: size)
        XCTAssertEqual(center.nx, 0, accuracy: 0.0001)
        XCTAssertEqual(center.ny, 0, accuracy: 0.0001)
        XCTAssertEqual(center.magnitude, 0, accuracy: 0.0001)
    }

    func testEdgesReachFullDeflection() {
        XCTAssertEqual(TiltVector(point: CGPoint(x: 200, y: 139.5), in: size).nx,
                       1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 0, y: 139.5), in: size).nx,
                       -1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 100, y: 279), in: size).ny,
                       1, accuracy: 0.0001)
        XCTAssertEqual(TiltVector(point: CGPoint(x: 100, y: 0), in: size).ny,
                       -1, accuracy: 0.0001)
    }

    func testOutOfBoundsPointsClamp() {
        let far = TiltVector(point: CGPoint(x: 400, y: -120), in: size)
        XCTAssertEqual(far.nx, 1, accuracy: 0.0001)
        XCTAssertEqual(far.ny, -1, accuracy: 0.0001)
    }

    func testZeroSizeDoesNotProduceNaN() {
        let vector = TiltVector(point: CGPoint(x: 10, y: 10), in: .zero)
        XCTAssertEqual(vector, .zero)
    }

    func testCombinedAxisMatchesSeparateRotations() {
        let tilt = 7.0
        for (nx, ny) in [(0.0, 0.0), (0.6, 0.0), (0.0, -0.8), (-0.5, 0.5),
                         (0.3, -0.9), (-0.7, -0.2), (0.0, 1.0), (-1.0, 0.0)] {
            let vector = TiltVector(nx: nx, ny: ny)
            let angle = vector.magnitude * tilt
            let axis = vector.axis
            XCTAssertEqual(Double(axis.y) * angle, nx * tilt, accuracy: 0.0001)
            XCTAssertEqual(Double(axis.x) * angle, -ny * tilt, accuracy: 0.0001)
        }
    }

    func testCornerKeepsDirectionAndClampsAngle() {
        for (nx, ny) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)] {
            let vector = TiltVector(nx: nx, ny: ny)
            XCTAssertEqual(vector.magnitude, 1, accuracy: 0.0001)
            let axis = vector.axis
            let length = (Double(axis.x) * Double(axis.x)
                          + Double(axis.y) * Double(axis.y)).squareRoot()
            XCTAssertEqual(length, 1, accuracy: 0.0001)
            let rootTwo = 2.0.squareRoot()
            XCTAssertEqual(Double(axis.x), -ny / rootTwo, accuracy: 0.0001)
            XCTAssertEqual(Double(axis.y), nx / rootTwo, accuracy: 0.0001)
        }
    }

    func testFlatCardHasStableAxis() {
        let axis = TiltVector.zero.axis
        XCTAssertEqual(Double(axis.x), 0)
        XCTAssertEqual(Double(axis.y), 1)
        XCTAssertEqual(Double(axis.z), 0)
    }
}
