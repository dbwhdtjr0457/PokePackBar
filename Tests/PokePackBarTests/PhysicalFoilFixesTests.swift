import AppKit
import Foundation
import XCTest
@testable import PokePackBar

/// 2026-10-16 실물 대조로 바로잡은 재질. 저장 판형은 그대로이고 그리는 재질과 보여 줄 이름만 바뀐다.
final class PhysicalFoilFixesTests: XCTestCase {

    private func spec(_ cardID: String, _ finish: CardFinish) throws -> FoilSpec {
        let index = try XCTUnwrap(CardIndex.shared)
        let card = try XCTUnwrap(index.card(cardID), cardID)
        return CardFinishResolver.resolve(cardID: card.id, setID: card.setID, originalRarity: card.rarity,
                                          tier: card.tier, visualKind: card.visualKind,
                                          explicitFinish: finish).spec
    }

    /// 대체 아트 VMAX 는 원본 데이터에 레인보우로 남아 있지만 질감 풀아트로 그린다.
    /// 같은 포켓몬의 진짜 레인보우(예: 블래키 214)는 그대로 무지개다.
    func testAlternateArtVMAXAreTexturedNotRainbow() throws {
        let index = try XCTUnwrap(CardIndex.shared)
        for id in PhysicalFoilFixes.swordShieldAlternateArtVMAX {
            XCTAssertEqual(index.card(id)?.rarity, "Rare Rainbow", "\(id) 데이터가 바뀌면 목록을 다시 본다")
            let foil = try spec(id, .rainbow)
            XCTAssertNotEqual(foil.pattern, .rainbow, id)
            XCTAssertEqual(foil.texture, .swordShieldEtched, id)
            XCTAssertEqual(PhysicalFoilFixes.displayedFinish(cardID: id, stored: .rainbow), .etched, id)
        }
        XCTAssertEqual(try spec("swsh7-214", .rainbow).pattern, .rainbow)
        XCTAssertEqual(L(.ko).cardFinishName(.rainbow, cardID: "swsh7-215"), L(.ko).cardFinishName(.etched))
        XCTAssertEqual(L(.ko).cardFinishName(.rainbow, cardID: "swsh7-214"), L(.ko).cardFinishName(.rainbow))
    }

    func testShiningLegendsArtistMewtwoIsTexturedNotRainbow() throws {
        let foil = try spec("sm35-78", .rainbow)
        XCTAssertEqual(foil.pattern, .waterWeb)
        XCTAssertEqual(foil.texture, .sunMoonEtched)
    }

    /// 트레이너즈 메일은 같은 세트의 금색 아이템처럼, 후기 XY 시크릿 EX 는 테두리가 금색이다.
    func testXYGoldSecretsUseGold() throws {
        let mail = try spec("xy7-100", .etched)
        XCTAssertEqual(mail.pattern, try spec("xy7-99", .gold).pattern)
        XCTAssertEqual(mail.border, .gold)
        XCTAssertEqual(PhysicalFoilFixes.displayedFinish(cardID: "xy7-100", stored: .etched), .gold)
        for id in PhysicalFoilFixes.xyGoldBorderSecretEX {
            let foil = try spec(id, .etched)
            XCTAssertEqual(foil.border, .gold, id)
            XCTAssertEqual(foil.texture, .xyEtched, id)
        }
    }

    /// 챔피언스 패스 이로치 리자몽 V 는 금색이 아니라 Shining Fates 이로치 V 와 같은 재질이다.
    /// 진짜 금색인 Shining Fates 에테르나 V(SV121)는 그대로 금색이다.
    func testChampionsPathShinyCharizardIsNotGold() throws {
        let charizard = try spec("swsh35-79", .gold)
        XCTAssertEqual(charizard.pattern, try spec("swsh45sv-SV120", .shinyFullArt).pattern)
        XCTAssertNotEqual(charizard.border, .gold)
        XCTAssertEqual(PhysicalFoilFixes.displayedFinish(cardID: "swsh35-79", stored: .gold), .shinyFullArt)
        XCTAssertEqual(try spec("swsh45sv-SV121", .gold).pattern, .swordShieldGold)
    }

    func testTimeSpaceDistortionHasAHoloBorder() throws {
        let foil = try spec("dp2-124", .holo)
        XCTAssertEqual(foil.coverage, .artAndBorder)
        XCTAssertEqual(foil.border, .holo)
    }

    /// Delta Species ~ Power Keepers 리버스는 그림 칸 전체가 아니라 배경이나 포켓몬 한쪽에만 포일이 있다.
    /// 실물 영상: HP 피카츄 78 은 배경만, DF 브케인 δ 45 는 포켓몬만.
    func testDeltaEraReversesFoilBackgroundOrPokemon() throws {
        XCTAssertEqual(try spec("ex13-78", .reverseHolo).coverage, .artBackground)
        XCTAssertEqual(try spec("ex15-45", .reverseHolo).coverage, .artSubject)
        XCTAssertEqual(try spec("ex13-1", .reverseHolo).coverage, .artSubject)
        XCTAssertEqual(try spec("ex14-2", .reverseHolo).coverage, .artSubject)
        let index = try XCTUnwrap(CardIndex.shared)
        let deltaCommon = try XCTUnwrap(index.cards(inSet: "ex13").first {
            index.card($0)?.name.contains("δ") == true && index.card($0)?.rarity == "Common"
        })
        XCTAssertEqual(try spec(deltaCommon, .reverseHolo).coverage, .artBackground)
        let keeper = try XCTUnwrap(index.cards(inSet: "ex16").first {
            index.card($0)?.visualKind?.supertype == .pokemon
        })
        XCTAssertEqual(try spec(keeper, .reverseHolo).coverage, .artBackground)
        for id in ["ex13-78", "ex15-45"] {
            XCTAssertEqual(try spec(id, .reverseHolo).pattern, .stampedMirror, "줄무늬 없는 평평한 홀로")
        }
    }

    /// 근거는 포켓몬 카드뿐이라 트레이너와 에너지는 예전처럼 그림 칸 전체다. δ 가 붙은 에너지도 같다.
    func testDeltaEraTrainerAndEnergyReversesKeepTheWholeArtWindow() throws {
        for id in ["ex13-85", "ex14-78", "ex15-72", "ex13-98", "ex14-88"] {
            XCTAssertEqual(try spec(id, .reverseHolo).coverage, .artWindow, id)
        }
    }
}

@MainActor
final class EXReverseRareAccentTests: XCTestCase {
    /// 델타종 리버스는 홀로 레어만 금색 이름과 HP 를 받는다. 일반 레어 리버스는 받지 않는다.
    func testDeltaSpeciesGoldNameOnlyOnHoloRareReverses() {
        XCTAssertTrue(HoloCardBody.showsEXReverseRareAccents(cardID: "ex11-1", finish: .reverseHolo, tier: .doubleRare))
        XCTAssertFalse(HoloCardBody.showsEXReverseRareAccents(cardID: "ex11-20", finish: .reverseHolo, tier: .rare))
        XCTAssertFalse(HoloCardBody.showsEXReverseRareAccents(cardID: "ex11-1", finish: .holo, tier: .doubleRare))
        // 다른 세트는 그대로: Legend Maker 는 레어 리버스도, Holon Phantoms 는 홀로 레어만.
        XCTAssertTrue(HoloCardBody.showsEXReverseRareAccents(cardID: "ex12-20", finish: .reverseHolo, tier: .rare))
        XCTAssertFalse(HoloCardBody.showsEXReverseRareAccents(cardID: "ex13-20", finish: .reverseHolo, tier: .rare))
    }
}

@MainActor
final class ArtworkMaskFailureTests: XCTestCase {
    /// 포켓몬을 찾지 못한 그림은 실패로 기록되어, 포켓몬만 칠할 포일이 그림 칸 전체로 돌아갈 수 있다.
    func testFailedSeparationIsRecorded() async throws {
        let blank = NSImage(size: NSSize(width: 120, height: 160), flipped: false) { rect in
            NSColor(white: 0.5, alpha: 1).setFill(); rect.fill(); return true
        }
        let art = CGRect(x: 0, y: 0, width: 1, height: 1)
        let key = ArtworkMaskCache.key(cardID: "test-blank", source: blank, art: art)
        XCTAssertFalse(ArtworkMaskCache.failed(key: key))
        let mask = await ArtworkMaskCache.prepare(cardID: "test-blank", source: blank, art: art)
        XCTAssertNil(mask)
        XCTAssertTrue(ArtworkMaskCache.failed(key: key))
    }
}
