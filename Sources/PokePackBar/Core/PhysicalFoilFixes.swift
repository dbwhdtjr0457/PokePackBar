import Foundation

/// 원본 데이터의 레어도 이름 때문에 실물과 다른 재질로 분류된 카드들.
///
/// 판형(`CardFinish`)은 보유 카드와 시세의 저장 키라 바꾸지 않는다. 바꾸면 이미 가진 카드가
/// 사라진 것처럼 보인다. 그리는 재질(`FoilMaterialCatalog`)과 화면에 적는 판형 이름만 고친다.
/// 목록마다 근거를 적는다(2026-10-16 실물 대조).
enum PhysicalFoilFixes {
    /// SWSH 대체 아트 VMAX 시크릿. 원본 데이터와 Bulbapedia 세트 목록이 같은 포켓몬의 레인보우와
    /// 함께 "Rare Rainbow" 로 적어 무지개로 그려졌다. 실물은 질감 있는 대체 아트다(예: 블래키
    /// VMAX 215/203 은 "Alternate Art Secret", 레인보우는 214/203).
    static let swordShieldAlternateArtVMAX: Set<String> = [
        "swsh5-168", "swsh5-170",
        "swsh6-201", "swsh6-203", "swsh6-205",
        "swsh7-205", "swsh7-209", "swsh7-212", "swsh7-215", "swsh7-218", "swsh7-220",
        "swsh8-269", "swsh8-270", "swsh8-271",
    ]

    /// 샤이닝 레전드 뮤츠-GX 78/73(아리타 미츠히로 일러스트). 레인보우 레어와 다른 "Secret
    /// Shining Holo" 판으로, SM 시대 GX 시크릿과 같은 질감 홀로다.
    static let sunMoonTexturedSecret: Set<String> = ["sm35-78"]

    /// xy7 이후의 금색 테두리 시크릿 EX. 스캔 테두리가 모두 금색인데 은색 테두리로 그렸다.
    /// 그보다 앞선 xy2~xy4 금색 시크릿은 `FoilMaterialCatalog` 가 이미 따로 다룬다.
    static let xyGoldBorderSecretEX: Set<String> = [
        "xy7-96", "xy7-97", "xy7-98", "xy8-163", "xy8-164",
        "xy9-123", "xy10-125", "xy11-115", "xy11-116",
    ]

    /// 같은 세트의 Energy Retrieval(xy7-99)과 같은 금색 시크릿 아이템. 풀아트 트레이너로 분류됐다.
    static let xyGoldItemStoredAsEtched: Set<String> = ["xy7-100"]

    /// 영문 첫 홀로 테두리 트레이너. 그림 칸만이 아니라 테두리도 홀로다(Bulbapedia).
    static let holoBorderTrainer: Set<String> = ["dp2-124"]

    /// 화면에 적을 판형. 저장된 판형 대신 실물의 재질 이름을 보여 준다.
    static func displayedFinish(cardID: String, stored: CardFinish) -> CardFinish {
        switch stored {
        case .rainbow where swordShieldAlternateArtVMAX.contains(cardID) || sunMoonTexturedSecret.contains(cardID):
            .etched
        case .etched where xyGoldItemStoredAsEtched.contains(cardID):
            .gold
        default:
            stored
        }
    }
}
