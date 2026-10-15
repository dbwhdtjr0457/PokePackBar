import Foundation

/// 트레이너 레벨과 로테이션 마켓의 문구.

// MARK: 레벨

extension L {
    var levelHeader: String { t("트레이너 레벨", "Trainer level", "トレーナーレベル", "Nivel de entrenador", "Niveau de dresseur", "Nível de treinador") }
    func levelShort(_ level: Int) -> String { t("Lv \(level)", "Lv \(level)", "Lv \(level)", "Nv \(level)", "Niv \(level)", "Nv \(level)") }
    func levelToNext(_ packs: Int) -> String {
        let n = packs.formatted()
        return t("다음 레벨까지 \(n)팩", "\(n) packs to next level", "次のレベルまで\(n)パック",
                 "\(n) sobres para el siguiente nivel", "\(n) boosters avant le niveau suivant",
                 "\(n) pacotes para o próximo nível")
    }
    var levelMax: String { t("최고 레벨", "Max level", "最大レベル", "Nivel máximo", "Niveau max", "Nível máximo") }
    func levelOpened(_ packs: Int) -> String {
        let n = packs.formatted()
        return t("지금까지 \(n)팩을 열었어요", "\(n) packs opened so far", "これまで\(n)パック開封",
                 "\(n) sobres abiertos hasta ahora", "\(n) boosters ouverts jusqu’ici", "\(n) pacotes abertos até agora")
    }
    func levelRewardsReady(_ levels: Int, packs: Int) -> String {
        t("받을 보상: 레벨 \(levels)개, 팩 \(packs)개", "Rewards ready: \(levels) levels, \(packs) packs",
          "受け取れる報酬：レベル\(levels)個、パック\(packs)個", "Recompensas: \(levels) niveles, \(packs) sobres",
          "Récompenses : \(levels) niveaux, \(packs) boosters", "Recompensas: \(levels) níveis, \(packs) pacotes")
    }
    var levelClaim: String { t("받기", "Claim", "受け取る", "Reclamar", "Récupérer", "Resgatar") }
    func levelClaimed(_ packs: Int, coupons: Int) -> String {
        coupons > 0
            ? t("팩 \(packs)개와 쿠폰 \(coupons)장을 받았어요. 팩 탭에서 열 수 있어요.",
                "Got \(packs) packs and \(coupons) coupons. Open them in the Packs tab.",
                "パック\(packs)個とクーポン\(coupons)枚を受け取りました。パックタブで開けられます。",
                "Recibiste \(packs) sobres y \(coupons) cupones. Ábrelos en la pestaña Sobres.",
                "\(packs) boosters et \(coupons) coupons reçus. Ouvrez-les dans l’onglet Boosters.",
                "Você recebeu \(packs) pacotes e \(coupons) cupons. Abra-os na aba Pacotes.")
            : t("팩 \(packs)개를 받았어요. 팩 탭에서 열 수 있어요.",
                "Got \(packs) packs. Open them in the Packs tab.",
                "パック\(packs)個を受け取りました。パックタブで開けられます。",
                "Recibiste \(packs) sobres. Ábrelos en la pestaña Sobres.",
                "\(packs) boosters reçus. Ouvrez-les dans l’onglet Boosters.",
                "Você recebeu \(packs) pacotes. Abra-os na aba Pacotes.")
    }
    var levelRewardRule: String {
        t("레벨마다 팩, 5레벨마다 반값 쿠폰, 10, 25, 50, 75, 100레벨에 칭호",
          "Packs every level, half-price coupons every 5 levels, titles at 10, 25, 50, 75 and 100",
          "レベルごとにパック、5レベルごとに半額クーポン、10・25・50・75・100で称号",
          "Sobres en cada nivel, cupones a mitad de precio cada 5 niveles y títulos en 10, 25, 50, 75 y 100",
          "Des boosters à chaque niveau, des coupons à moitié prix tous les 5 niveaux, des titres aux niveaux 10, 25, 50, 75 et 100",
          "Pacotes a cada nível, cupons pela metade a cada 5 níveis e títulos nos níveis 10, 25, 50, 75 e 100")
    }
    func levelNextUnlock(_ level: Int) -> String {
        switch level {
        case LevelRules.oripaLevel:
            return t("레벨 \(level)에 오리파가 열려요", "Oripa unlocks at level \(level)",
                     "レベル\(level)でオリパが解放されます", "La oripa se desbloquea en el nivel \(level)",
                     "L’oripa se débloque au niveau \(level)", "A oripa é liberada no nível \(level)")
        case 5:
            return t("레벨 \(level)에 한 번에 100팩까지 열 수 있어요", "Open up to 100 packs at once from level \(level)",
                     "レベル\(level)で一度に100パックまで開けられます", "Desde el nivel \(level) abres hasta 100 sobres a la vez",
                     "Jusqu’à 100 boosters d’un coup dès le niveau \(level)", "A partir do nível \(level) abra até 100 pacotes de uma vez")
        default:
            return t("레벨 \(level)에 한 번에 여는 팩 수 제한이 풀려요", "No limit on packs per opening from level \(level)",
                     "レベル\(level)で一度に開けるパック数の制限がなくなります",
                     "Desde el nivel \(level) no hay límite de sobres por apertura",
                     "Plus de limite de boosters par ouverture dès le niveau \(level)",
                     "A partir do nível \(level) não há limite de pacotes por abertura")
        }
    }
    func levelOripaLocked(_ level: Int, packsLeft: Int) -> String {
        let n = packsLeft.formatted()
        return t("오리파는 레벨 \(level)에 열려요. 팩을 \(n)개 더 열면 돼요.",
                 "Oripa unlocks at level \(level). Open \(n) more packs.",
                 "オリパはレベル\(level)で解放されます。あと\(n)パック開けてください。",
                 "La oripa se desbloquea en el nivel \(level). Abre \(n) sobres más.",
                 "L’oripa se débloque au niveau \(level). Ouvrez encore \(n) boosters.",
                 "A oripa é liberada no nível \(level). Abra mais \(n) pacotes.")
    }
    func levelOpenLimit(_ limit: Int, nextLevel: Int) -> String {
        t("한 번에 \(limit)팩까지, 레벨 \(nextLevel)에 늘어나요",
          "Up to \(limit) at once, more at level \(nextLevel)",
          "一度に\(limit)パックまで、レベル\(nextLevel)で増えます",
          "Hasta \(limit) a la vez, más en el nivel \(nextLevel)",
          "Jusqu’à \(limit) à la fois, plus au niveau \(nextLevel)",
          "Até \(limit) de uma vez, mais no nível \(nextLevel)")
    }

    /// 레벨 칭호. 그 칭호가 열리는 레벨로 고른다.
    func levelTitle(_ level: Int) -> String {
        switch level {
        case 10: return t("새싹 트레이너", "Rookie Trainer", "かけだしトレーナー", "Entrenador novato", "Dresseur débutant", "Treinador novato")
        case 25: return t("팩 뜯기 장인", "Pack Ripper", "パック開封の達人", "Maestro de sobres", "Maître des boosters", "Mestre dos pacotes")
        case 50: return t("박스 브레이커", "Box Breaker", "ボックスブレイカー", "Rompecajas", "Briseur de boîtes", "Quebra-caixas")
        case 75: return t("케이스 헌터", "Case Hunter", "ケースハンター", "Cazador de cajas", "Chasseur de caisses", "Caçador de caixas")
        default: return t("전설의 개봉가", "Legendary Opener", "伝説の開封者", "Abridor legendario", "Ouvreur légendaire", "Abridor lendário")
        }
    }
    func levelTitleOption(_ level: Int) -> String {
        t("\(levelTitle(level)) (레벨 \(level))", "\(levelTitle(level)) (Lv \(level))", "\(levelTitle(level))（Lv \(level)）",
          "\(levelTitle(level)) (Nv \(level))", "\(levelTitle(level)) (Niv \(level))", "\(levelTitle(level)) (Nv \(level))")
    }
}
