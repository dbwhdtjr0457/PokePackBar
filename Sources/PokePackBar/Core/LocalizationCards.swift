import Foundation

/// 카드 게임 문구. 기존 문구 파일과 분리해 둔다 — 컴패니언을 걷어낸 뒤 남은 문구와
/// 새로 들어온 문구를 구분해서 보기 위한 것이다.
extension L {

    // MARK: 탭
    var packsTab: String { t("팩", "Packs", "パック", "Sobres", "Boosters", "Pacotes") }

    // MARK: 시세
    var marketPrice: String { t("시세", "Market", "相場", "Mercado", "Marché", "Mercado") }
    func dexTotalValue(_ amount: String) -> String {
        t("총 가치 \(amount)", "Total value \(amount)", "総価値 \(amount)",
          "Valor total \(amount)", "Valeur totale \(amount)", "Valor total \(amount)")
    }
    /// 개봉한 팩에서 나온 카드값의 합.
    func packTotalValue(_ amount: String) -> String {
        t("총 가치 \(amount)", "Total value \(amount)", "総価値 \(amount)",
          "Valor total \(amount)", "Valeur totale \(amount)", "Valor total \(amount)")
    }
    var collectionValue: String { t("컬렉션 가치", "Collection value", "コレクション価値",
                                    "Valor de la colección", "Valeur de la collection",
                                    "Valor da coleção") }
    /// 카드 상세 값 표에서 시세의 출처 줄 라벨.
    var priceBasis: String { t("기준", "Basis", "基準", "Base", "Base", "Base") }
    var marketHoldings: String { t("보유", "Holdings", "保有", "En posesión", "En stock", "Em posse") }
    func cardFinishName(_ finish: CardFinish) -> String {
        switch finish {
        case .normal: return t("일반", "Non-foil", "ノーマル", "Normal", "Standard", "Normal")
        case .holo: return t("홀로", "Holo", "ホロ", "Holo", "Holo", "Holo")
        case .reverseHolo: return t("역홀로", "Reverse holo", "リバースホロ", "Holo inverso", "Holo inversé", "Holo reverso")
        case .patternedReverse: return t("볼·로켓단 미러", "Ball / Team Rocket mirror", "ボール・ロケット団ミラー", "Espejo Ball / Team Rocket", "Miroir Ball / Team Rocket", "Espelho Ball / Equipe Rocket")
        case .fullArt: return t("풀아트 홀로", "Full-art foil", "フルアート", "Full Art", "Full Art", "Full Art")
        case .etched: return t("텍스처 홀로", "Textured foil", "テクスチャーホロ", "Holo texturizado", "Holo texturé", "Holo texturizado")
        case .radiant: return t("찬란한 홀로", "Radiant foil", "かがやくホロ", "Holo Radiante", "Holo Radieux", "Holo Radiante")
        case .amazingRare: return t("어메이징 홀로", "Amazing Rare foil", "アメイジングレア", "Amazing Rare", "Amazing Rare", "Amazing Rare")
        case .rainbow: return t("레인보우", "Rainbow foil", "レインボー", "Arcoíris", "Arc-en-ciel", "Arco-íris")
        case .gold: return t("골드", "Gold foil", "ゴールド", "Dorada", "Dorée", "Dourada")
        case .shiny: return t("이로치 홀로", "Shiny foil", "色違いホロ", "Holo variocolor", "Holo chromatique", "Holo Brilhante")
        case .shinyFullArt: return t("이로치 풀아트 홀로", "Shiny full-art foil", "色違いフルアートホロ", "Full Art variocolor", "Full Art chromatique", "Full Art brilhante")
        case .aceSpec: return t("ACE SPEC 홀로", "ACE SPEC foil", "ACE SPECホロ", "Holo ACE SPEC", "Holo ACE SPEC", "Holo ACE SPEC")
        case .pokeBall: return t("몬스터볼 미러", "Poké Ball parallel", "モンスターボールミラー", "Paralela Poké Ball", "Parallèle Poké Ball", "Paralela Poké Ball")
        case .masterBall: return t("마스터볼 미러", "Master Ball parallel", "マスターボールミラー", "Paralela Master Ball", "Parallèle Master Ball", "Paralela Master Ball")
        case .celebrationsClassic: return t("클래식 컬렉션", "Classic Collection foil", "クラシックコレクション", "Colección clásica", "Collection classique", "Coleção clássica")
        case .radiantCollection: return t("래디언트 컬렉션 코팅", "Radiant Collection foil", "ラディアントコレクションホロ", "Holo Radiant Collection", "Holo Radiant Collection", "Holo Radiant Collection")
        case .prism: return t("프리즘스타 홀로", "Prism Star foil", "プリズムスターホロ", "Holo Estrella Prisma", "Holo Prisme Étoile", "Holo Estrela Prisma")
        case .breakFoil: return t("BREAK 골드 홀로", "BREAK gold foil", "BREAKゴールドホロ", "Holo dorado BREAK", "Holo doré BREAK", "Holo dourado BREAK")
        case .blackWhite: return t("블랙·화이트 레어", "Black & White rare foil", "白黒レア", "Rara Blanco y Negro", "Rare noir et blanc", "Rara preta e branca")
        case .megaAttack: return t("메가어택 홀로", "Mega Attack foil", "メガアタックホロ", "Holo Megaataque", "Holo Méga-Attaque", "Holo Mega Ataque")
        }
    }
    func marketPriceSource(_ date: String) -> String {
        t("TCGplayer 시장가 · \(date) 기준",
          "TCGplayer market price, as of \(date)",
          "TCGplayer 市場価格・\(date) 時点",
          "Precio de mercado de TCGplayer, a \(date)",
          "Prix du marché TCGplayer, au \(date)",
          "Preço de mercado da TCGplayer, em \(date)")
    }

    // MARK: 메뉴바 카드
    var menuBarCardLabel: String { t("메뉴바에 카드 표시", "Show a card in the menu bar", "メニューバーにカードを表示",
                                     "Mostrar una carta en la barra de menús", "Afficher une carte dans la barre de menus",
                                     "Mostrar uma carta na barra de menus") }
    var favoriteCardSet: String { t("메뉴바에 올리기", "Put in the menu bar", "メニューバーに置く",
                                    "Poner en la barra de menús", "Mettre dans la barre de menus",
                                    "Colocar na barra de menus") }
    var favoriteCardClear: String { t("메뉴바에서 내리기", "Take out of the menu bar", "メニューバーから外す",
                                      "Quitar de la barra de menús", "Retirer de la barre de menus",
                                      "Remover da barra de menus") }
    var favoriteCardAuto: String { t("가장 높은 등급 (자동)", "Highest rarity (automatic)", "最高レアリティ（自動）",
                                     "Mayor rareza (automático)", "Rareté la plus élevée (auto)",
                                     "Maior raridade (automático)") }
    var favoriteCardNone: String { t("올릴 카드가 없어요", "No card to show yet", "表示できるカードがありません",
                                     "Todavía no hay carta", "Aucune carte à afficher",
                                     "Nenhuma carta para mostrar") }

    // MARK: 지갑
    var walletBalance: String { t("쓸 수 있는 금액", "Spendable", "使える金額",
                                   "Disponible", "Disponible", "Disponível") }
    var walletRateTitle: String { t("토큰은 얼마인가요?", "What is a token worth?",
                                     "トークンはいくら？", "¿Cuánto vale un token?",
                                     "Combien vaut un token ?", "Quanto vale um token?") }
    /// 토큰 한 개는 5원도 안 되어 그대로 적으면 감이 오지 않는다. 100만 개를 기준으로 적는다.
    /// 한 줄이다 — 환산이 어디서 왔는지까지 늘어놓으면 읽기 전에 닫는다.
    func walletRateBody(_ tokens: String, _ money: String) -> String {
        t("토큰 \(tokens)개 = \(money)", "\(tokens) tokens = \(money)",
           "トークン \(tokens)個 = \(money)", "\(tokens) tokens = \(money)",
           "\(tokens) tokens = \(money)", "\(tokens) tokens = \(money)")
    }
    var awaitingUsage: String { t("사용량을 아직 못 읽었어요. AI 코딩 도구를 한 번 써 보세요.",
                                   "No usage yet. Use an AI coding tool once to get started.",
                                   "使用量がまだありません。AI コーディングツールを一度使ってみてください。",
                                   "Aún no hay uso. Usa una herramienta de IA una vez para empezar.",
                                   "Aucun usage pour l'instant. Utilise un outil d'IA une fois pour démarrer.",
                                   "Ainda sem uso. Use uma ferramenta de IA uma vez para começar.") }

    func updateAvailableHelp(_ version: String) -> String {
        t("새 버전 \(version) 으로 업데이트", "Update to \(version)", "\(version) に更新",
           "Actualizar a \(version)", "Mettre à jour vers \(version)", "Atualizar para \(version)")
    }

    // MARK: 상점
    func packName(_ setName: String) -> String {
        t("\(setName) 팩", "\(setName) Pack", "\(setName) パック",
           "Sobre de \(setName)", "Booster \(setName)", "Pacote \(setName)")
    }
    func packContents(_ count: Int) -> String {
        t("카드 \(count)장", "\(count) cards", "カード \(count)枚",
           "\(count) cartas", "\(count) cartes", "\(count) cartas")
    }

    /// 실제 밀봉 팩 구성. 확장팩 카드와 별도 동봉 에너지·코드 카드를 구분한다.
    func packContents(_ contents: PackContents) -> String {
        let game = t("게임 카드 \(contents.gameCardCount)장",
                     "\(contents.gameCardCount) game cards",
                     "ゲームカード\(contents.gameCardCount)枚",
                     "\(contents.gameCardCount) cartas de juego",
                     "\(contents.gameCardCount) cartes de jeu",
                     "\(contents.gameCardCount) cartas de jogo")
        var parts = [game]
        if contents.energyCardCount > 0 {
            parts.append(t("기본 에너지 \(contents.energyCardCount)장",
                           "\(contents.energyCardCount) Basic Energy",
                           "基本エネルギー\(contents.energyCardCount)枚",
                           "\(contents.energyCardCount) Energía Básica",
                           "\(contents.energyCardCount) Énergie de base",
                           "\(contents.energyCardCount) Energia Básica"))
        }
        if contents.codeCardCount > 0 {
            parts.append(t("코드 카드 \(contents.codeCardCount)장",
                           "\(contents.codeCardCount) code card",
                           "コードカード\(contents.codeCardCount)枚",
                           "\(contents.codeCardCount) carta de código",
                           "\(contents.codeCardCount) carte à code",
                           "\(contents.codeCardCount) carta de código"))
        }
        return parts.joined(separator: " + ")
    }

    func sealedPackMarketSource(_ date: String) -> String {
        t("밀봉 팩 TCGplayer 시장가 · \(date) 기준",
          "Sealed pack TCGplayer market, as of \(date)",
          "未開封パック TCGplayer 市場価格・\(date) 時点",
          "Mercado TCGplayer del sobre sellado, a \(date)",
          "Marché TCGplayer du booster scellé, au \(date)",
          "Mercado TCGplayer do pacote lacrado, em \(date)")
    }

    func sealedPackSafetyFloorSource(_ quote: String, _ date: String) -> String {
        t("밀봉 시세 \(quote) (\(date)) · 카드 기대값 안전 하한 적용",
          "Sealed quote \(quote) (\(date)) · expected-value safety floor applied",
          "未開封相場 \(quote)（\(date)）・期待値の安全下限を適用",
          "Cotización sellada \(quote) (\(date)) · mínimo seguro por valor esperado",
          "Cote scellée \(quote) (\(date)) · plancher de sécurité appliqué",
          "Cotação lacrada \(quote) (\(date)) · piso seguro por valor esperado")
    }

    var estimatedPackValueSource: String {
        t("밀봉 시세 없음 · 카드 기대값으로 계산",
          "No sealed quote · priced from expected card value",
          "未開封相場なし・カード期待値から算出",
          "Sin cotización sellada · valor esperado de las cartas",
          "Pas de cote scellée · valeur attendue des cartes",
          "Sem cotação lacrada · valor esperado das cartas")
    }

    var observedPrismaticParallelRates: String {
        t("병렬판형 관측치: 몬스터볼 33.10% · 마스터볼 4.92% (TCGplayer 1,200팩 이상, 공식 확률 아님)",
          "Observed parallels: Poké Ball 33.10% · Master Ball 4.92% (1,200+ TCGplayer packs; not official)",
          "並行柄の実測値：モンスターボール33.10%・マスターボール4.92%（TCGplayer 1,200パック超、非公式）",
          "Paralelas observadas: Poké Ball 33,10 % · Master Ball 4,92 % (más de 1.200 sobres; no oficial)",
          "Parallèles observées : Poké Ball 33,10 % · Master Ball 4,92 % (plus de 1 200 boosters ; non officiel)",
          "Paralelas observadas: Poké Ball 33,10% · Master Ball 4,92% (mais de 1.200 pacotes; não oficial)")
    }

    /// 팩 한 줄 소개. 그 세트가 왜 특별한지 실제 사실로 적는다 —
    /// 이름과 연도만으로는 어느 팩을 살지 정하기 어렵다.
    ///
    /// 한국어와 영어만 쓴다. 사실 서술이라 나머지 언어는 영어로 둔다.
    func packBlurb(_ setID: String) -> String? {
        switch setID {
        case "base1":
            return blurb("포켓몬 카드가 시작된 자리. 1999년 첫 세트로, 초판 리자몽이 여기서 나왔습니다.",
                         "Where it all began. The 1999 first set, home of the original Charizard.")
        case "neo1":
            return blurb("2세대의 문을 연 세트. 악·강철 타입과 베이비 포켓몬이 처음 등장했습니다.",
                         "Opens the Johto era — the debut of Darkness and Metal types, and Baby Pokémon.")
        case "xy12":
            return blurb("20주년 기념 복각. 1999년 초판의 그림과 구성을 현대 규칙으로 다시 냈습니다.",
                         "The 20th-anniversary throwback: 1999 artwork and lineup, rebuilt for modern rules.")
        case "sm115":
            return blurb("이로치 카드를 모으는 '샤이니 볼트'가 처음 붙은 세트. 75종이 넘습니다.",
                         "The set that introduced the Shiny Vault — over 75 Shiny cards to chase.")
        case "swsh45":
            return blurb("샤이니 볼트를 100종 넘게 키운 세트. 이로치를 노린다면 여기입니다.",
                         "Shiny Vault grown past 100 cards. The set to open if you are hunting Shinies.")
        case "cel25":
            return blurb("25주년 기념 세트. 역대 명장면 카드를 복각해 25장만 담은 작은 팩입니다.",
                         "The 25th-anniversary set: 25 reprinted classics in a deliberately tiny pack.")
        case "cel30":
            return blurb("30주년 기념 세트. 피카츄 레어 1장 포함 홀로 5장과 별도 홀로 에너지 1장. 세부 봉입률은 시뮬레이터 추정치입니다.",
                         "Five foil cards including one Pikachu Rare, plus one foil Energy. Unpublished sheet odds are simulator estimates.")
        case "me2pt5":
            return blurb("메가어택 레어가 등장한 Ascended Heroes. 새 등급의 봉입률은 공식 확률이 아닌 시뮬레이터 추정치입니다.",
                         "Ascended Heroes introduces Mega Attack Rare. New-rarity pull rates are simulator estimates, not official odds.")
        case "me3", "me4", "me5":
            return blurb("2026년 메가진화 시리즈. 10장과 별도 기본 에너지 구성. 세부 봉입률은 현대 영문판 추정 모델을 사용합니다.",
                         "A 2026 Mega Evolution expansion: ten cards plus Basic Energy. Detailed odds use an estimated modern English model.")
        case "swsh12pt5":
            return blurb("소드·실드 시리즈를 마무리한 세트. 갈라르 갤러리 일러스트가 들어 있습니다.",
                         "The send-off for Sword & Shield, carrying the Galarian Gallery illustrations.")
        case "sv3pt5":
            return blurb("1세대 151마리를 빠짐없이 담은 세트. 관동 지방을 통째로 모을 수 있습니다.",
                         "All 151 originals in one set — the whole Kanto roster, collectible end to end.")
        case "sv8pt5":
            return blurb("이브이 진화형이 주인공인 세트. 몬스터볼·마스터볼 무늬 카드가 여기서 나옵니다.",
                         "Built around the Eeveelutions, with the Poké Ball and Master Ball patterned cards.")
        case "sv10":
            return blurb("로켓단이 전면에 선 세트. 트레이너가 소유한 포켓몬 카드가 돌아왔습니다.",
                         "Team Rocket takes the lead, and trainer-owned Pokémon cards return.")
        default:
            return nil
        }
    }

    private func blurb(_ ko: String, _ en: String) -> String {
        lang == .ko ? ko : en
    }

    /// 원본 등급 이름을 **커뮤니티 약칭**으로 옮긴다.
    ///
    /// 우리 10칸(`CardTier`)은 게임 규칙용으로 접은 것이다. 팩 확률표와 도감이 그 칸으로
    /// 돌아가야 하고, 33종을 그대로 쓰면 세트마다 표 모양이 달라져 못 쓴다. 그래서 접었다.
    ///
    /// 그런데 접은 탓에 「이 카드가 무슨 등급인가」에 답하지 못한다 — 찬란한·ACE SPEC·
    /// BREAK·LV.X 가 모두 RRR 로 뭉쳐 있다. 국내 커뮤니티는 그것들을 각각 K·ACE·BREAK·LV.X
    /// 라 부르므로, 카드 상세에서는 그 이름으로 적어 준다.
    ///
    /// 영문/일문 판은 원문 등급명을 그대로 쓴다 — 약칭은 일본판 표기에서 온 국내 관용이다.
    func rarityLabel(_ source: String) -> String? {
        switch source {
        case "Common":                      return t("C", "Common", "C", "C", "C", "C")
        case "Uncommon":                    return t("U", "Uncommon", "U", "U", "U", "U")
        case "Rare":                        return t("R", "Rare", "R", "R", "R", "R")
        case "Rare Holo":                   return t("홀로 R", "Holo Rare", "R", "R holo", "R holo", "R holo")
        case "Double Rare":                 return t("RR", "Double Rare", "RR", "RR", "RR", "RR")
        case "Rare Holo EX":                return t("ex (구)", "Holo ex", "ex", "ex", "ex", "ex")
        case "Rare Holo GX":                return t("GX", "Holo GX", "GX", "GX", "GX", "GX")
        case "Rare Holo V":                 return t("V", "Holo V", "V", "V", "V", "V")
        case "Rare Holo VMAX":              return t("VMAX", "Holo VMAX", "VMAX", "VMAX", "VMAX", "VMAX")
        case "Rare Holo VSTAR":             return t("VSTAR", "Holo VSTAR", "VSTAR", "VSTAR", "VSTAR", "VSTAR")
        case "Rare Holo LV.X":              return t("LV.X", "Holo LV.X", "LV.X", "LV.X", "LV.X", "LV.X")
        case "Rare Prime":                  return t("Prime", "Prime", "Prime", "Prime", "Prime", "Prime")
        case "Rare Prism Star":             return t("PR (프리즘스타)", "Prism Star", "PR", "Prism Star", "Prism Star", "Prism Star")
        case "Rare ACE", "ACE SPEC Rare":   return t("ACE", "ACE SPEC", "ACE", "ACE", "ACE", "ACE")
        case "Rare BREAK":                  return t("BREAK", "BREAK", "BREAK", "BREAK", "BREAK", "BREAK")
        case "Radiant Rare":                return t("K (찬란한)", "Radiant Rare", "K", "Radiante", "Radiant", "Radiante")
        case "Amazing Rare":                return t("A (어메이징)", "Amazing Rare", "A", "Amazing", "Amazing", "Amazing")
        case "Illustration Rare":           return t("AR", "Illustration Rare", "AR", "AR", "AR", "AR")
        case "Special Illustration Rare":   return t("SAR", "Special Illustration Rare", "SAR", "SAR", "SAR", "SAR")
        case "Rare Ultra":                  return t("SR (풀아트)", "Full Art SR", "SR", "SR", "SR", "SR")
        case "Ultra Rare":                  return t("SR", "Ultra Rare", "SR", "SR", "SR", "SR")
        case "Shiny Rare":                  return t("S (샤이니)", "Shiny Rare", "S", "Shiny", "Shiny", "Shiny")
        case "Shiny Ultra Rare":            return t("SSR (샤이니)", "Shiny Ultra Rare", "SSR", "SSR", "SSR", "SSR")
        case "Rare Secret":                 return t("UR (시크릿)", "Secret Rare", "UR", "UR", "UR", "UR")
        case "Rare Rainbow":                return t("UR (레인보우)", "Rainbow Rare", "UR", "UR", "UR", "UR")
        case "Hyper Rare":                  return t("HR", "Hyper Rare", "HR", "HR", "HR", "HR")
        case "Mega Hyper Rare":             return t("MUR", "Mega Hyper Rare", "MUR", "MUR", "MUR", "MUR")
        case "Black White Rare":            return t("BWR", "Black White Rare", "BWR", "BWR", "BWR", "BWR")
        case "Rare Holo Star":              return t("★ (골드스타)", "Gold Star", "★", "Gold Star", "Gold Star", "Gold Star")
        case "Rare Shining":                return t("빛나는", "Shining", "光り", "Shining", "Shining", "Shining")
        case "LEGEND":                      return t("LEGEND", "LEGEND", "LEGEND", "LEGEND", "LEGEND", "LEGEND")
        case "Promo":                       return t("P (프로모)", "Promo", "P", "Promo", "Promo", "Promo")
        default:                            return nil
        }
    }

    // MARK: 컬렉션 정렬
    var sortBy: String { t("정렬", "Sort", "並び替え", "Orden", "Tri", "Ordem") }
    var sortByValue: String { t("가격순", "By price", "価格順", "Por precio", "Par prix", "Por preço") }
    var sortByTier: String { t("등급순", "By rarity", "レアリティ順",
                                "Por rareza", "Par rareté", "Por raridade") }
    /// 「획득 순」은 방향이 두 가지로 읽힌다. 최근 것부터라고 못 박는다 —
    /// 컬렉션에서 찾는 것은 대개 방금 얻은 카드다.
    var sortByAcquired: String { t("최근 획득순", "Recently added", "入手が新しい順",
                                    "Añadidas hace poco", "Ajoutées récemment",
                                    "Adicionadas recentemente") }
    var sortByDuplicates: String { t("중복 많은순", "Most duplicates", "重複が多い順",
                                      "Más repetidas", "Plus de doublons", "Mais repetidas") }
    /// 세트 안 카드 번호 순서. 세트를 하나 골라 두고 실물 바인더처럼 훑을 때 쓴다.
    var sortByNumber: String { t("번호순", "By number", "番号順", "Por número", "Par numéro", "Por número") }
    /// 컬렉션 보기 줄의 좁은 검색창에 들어가므로 짧게 둔다.
    var searchCards: String { t("검색", "Search", "検索", "Buscar", "Chercher", "Buscar") }
    var collectionSearchPlaceholder: String {
        t("이름이나 카드 번호로 찾기", "Search by name or card number", "名前かカード番号で検索",
          "Buscar por nombre o número", "Chercher par nom ou numéro", "Buscar por nome ou número")
    }

    // MARK: 통계
    var statsTab: String { t("통계", "Stats", "統計", "Stats", "Stats", "Stats") }
    var statsOpening: String { t("개봉", "Opening", "開封", "Apertura", "Ouverture", "Abertura") }
    var statsPacksOpened: String { t("개봉한 팩", "Packs opened", "開封したパック",
                                     "Sobres abiertos", "Boosters ouverts", "Pacotes abertos") }
    /// 보유 장수에 판 장수를 더한 값이라는 것을 라벨에 적는다.
    var statsCardsPulled: String { t("얻은 카드 (보유 + 판매)", "Cards pulled (kept + sold)",
                                     "入手カード（所持＋売却）", "Cartas obtenidas (guardadas + vendidas)",
                                     "Cartes obtenues (gardées + vendues)", "Cartas obtidas (guardadas + vendidas)") }
    func statsSpecialPacks(_ window: String) -> String {
        t("특수팩 (최근 \(window)팩)", "Special packs (last \(window))", "特殊パック（直近\(window)）",
          "Sobres especiales (últimos \(window))", "Boosters spéciaux (\(window) derniers)",
          "Pacotes especiais (últimos \(window))")
    }
    func statsBestPack(_ window: String) -> String {
        t("최고 가치 팩 (최근 \(window)팩)", "Best pack (last \(window))", "最高価値パック（直近\(window)）",
          "Mejor sobre (últimos \(window))", "Meilleur booster (\(window) derniers)",
          "Melhor pacote (últimos \(window))")
    }
    var statsUnique: String { t("보유 종류", "Unique cards", "所持種類", "Cartas distintas",
                                "Cartes distinctes", "Cartas distintas") }
    var statsCopies: String { t("보유 장수", "Copies held", "所持枚数", "Copias", "Exemplaires", "Cópias") }
    var statsTopCard: String { t("가장 비싼 보유 카드", "Most valuable card", "最も高い所持カード",
                                 "Carta más valiosa", "Carte la plus chère", "Carta mais valiosa") }
    var statsTokens: String { t("토큰", "Tokens", "トークン", "Tokens", "Jetons", "Tokens") }
    var statsTokensSpent: String { t("쓴 토큰", "Tokens spent", "使ったトークン",
                                     "Tokens gastados", "Jetons dépensés", "Tokens gastos") }
    var statsTokensRefunded: String { t("판매로 돌려받은 토큰", "Tokens from sales", "売却で戻ったトークン",
                                        "Tokens por ventas", "Jetons des ventes", "Tokens de vendas") }
    var statsCardsSold: String { t("판매한 카드", "Cards sold", "売却したカード",
                                   "Cartas vendidas", "Cartes vendues", "Cartas vendidas") }
    var statsHistoryNote: String {
        t("개봉 기록은 최근 1,000팩까지만 남아 특수팩과 최고 가치 팩은 그 안에서 셉니다.",
          "Opening history keeps the last 1,000 packs, so special and best packs are counted within it.",
          "開封記録は直近1,000パックまでのため、特殊パックと最高価値パックはその中で数えます。",
          "El historial guarda los últimos 1.000 sobres; los especiales y el mejor se cuentan ahí.",
          "L'historique garde les 1 000 derniers boosters ; spéciaux et meilleur y sont comptés.",
          "O histórico guarda os últimos 1.000 pacotes; especiais e o melhor são contados nele.")
    }
    /// 카드를 처음 얻은 날. 기록이 있는 카드에만 붙는다.
    func cardFirstAcquired(_ date: String) -> String {
        t("처음 얻은 날 \(date)", "First obtained \(date)", "初入手 \(date)",
           "Primera vez \(date)", "Obtenue le \(date)", "Primeira vez \(date)")
    }

    var packOdds: String { t("시뮬레이터 등급 확률", "Simulator odds by rarity", "シミュレーターのレアリティ確率",
                              "Probabilidad simulada por rareza", "Probabilités simulées par rareté",
                              "Chance simulada por raridade") }
    /// 이 팩에서 나올 수 있는 카드를 다 보여 주는 화면으로 들어가는 말.
    var packSeeCards: String { t("나올 수 있는 카드", "Cards in this pack", "出るカード一覧",
                                  "Cartas de este sobre", "Cartes de ce booster",
                                  "Cartas deste pacote") }
    /// 카드 상세에서 그 팩을 사러 가는 말.
    var packGoBuy: String { t("이 팩 사러 가기", "Buy this pack", "このパックを買う",
                               "Comprar este sobre", "Acheter ce booster", "Comprar este pacote") }
    /// 확정 한 장과 천장을 한 줄로. 표를 칸별로 쪼개는 대신 이 줄로 보장을 알린다.
    func packGuaranteeNote(_ guaranteed: Int, pity: Int) -> String {
        t("시뮬레이터 규칙: 레어 이상 \(guaranteed)장 · 레어만 \(pity)팩 연속이면 다음은 RR 이상",
           "Simulator rule: \(guaranteed) rare+ per pack · RR+ after \(pity) plain-rare packs",
           "シミュレーター規則：レア以上\(guaranteed)枚・レアのみ\(pity)パック連続で次はRR以上",
           "Regla del simulador: \(guaranteed) rara+ · RR+ tras \(pity) sobres solo raros",
           "Règle du simulateur : \(guaranteed) rare+ · RR+ après \(pity) boosters sans hit",
           "Regra do simulador: \(guaranteed) rara+ · RR+ após \(pity) pacotes só raros")
    }

    var packOddsColumns: String { t("카드 한 장 기준", "Per card", "カード1枚あたり",
                                     "Por carta", "Par carte", "Por carta") }
    var packQuantity: String { t("수량", "Quantity", "数量", "Cantidad", "Quantité", "Quantidade") }
    var packQuantityInputTitle: String {
        t("수량 직접 입력", "Enter quantity", "数量を直接入力", "Ingresar cantidad",
          "Saisir la quantité", "Inserir quantidade")
    }
    var packQuantityInputPlaceholder: String {
        t("양의 정수", "Positive whole number", "1以上の整数", "Número entero positivo",
          "Nombre entier positif", "Número inteiro positivo")
    }
    func packQuantityInputRange(_ maximum: Int) -> String {
        t("1~\(maximum)개 사이로 입력하세요.", "Enter a whole number from 1 to \(maximum).",
          "1から\(maximum)までの整数を入力してください。",
          "Introduce un número entero entre 1 y \(maximum).",
          "Saisissez un nombre entier entre 1 et \(maximum).",
          "Insira um número inteiro entre 1 e \(maximum).")
    }
    func buyCount(_ n: Int) -> String {
        t("\(n)개 구매", "Buy \(n)", "\(n)個 購入", "Comprar \(n)", "Acheter \(n)", "Comprar \(n)")
    }

    // MARK: 팩
    var packsEmptyTitle: String { t("가진 팩이 없어요", "No packs yet", "パックがありません",
                                     "Sin sobres", "Aucun booster", "Nenhum pacote") }
    var packsEmptyHint: String { t("상점에서 팩을 사거나, 사용 한도를 다 채워 보너스 팩을 받으세요.",
                                     "Buy one in the shop, or fill a usage limit for a bonus pack.",
                                     "ショップで買うか、使用上限を使い切ってボーナスパックを受け取りましょう。",
                                     "Cómpralo en la tienda o alcanza un límite para un sobre extra.",
                                     "Achète-en un, ou atteins une limite pour un booster bonus.",
                                     "Compre na loja ou atinja um limite para um pacote bônus.") }
    var packPreparing: String { t("카드를 꺼내는 중…", "Getting the cards ready…", "カードを準備中…",
                                    "Preparando las cartas…", "Préparation des cartes…", "Preparando as cartas…") }
    var packTearTitle: String { t("밀어서 뜯기", "Swipe to tear open", "スワイプして開封",
                                    "Desliza para abrir", "Glisse pour ouvrir", "Deslize para abrir") }
    var packTearHint: String { t("윗부분을 옆으로 밀거나, 팩을 눌러 열어요",
                                   "Swipe across the top, or click the pack",
                                   "上の部分を横になぞるか、パックをクリック",
                                   "Desliza por arriba o haz clic en el sobre",
                                   "Glisse le long du haut ou clique sur le booster",
                                   "Deslize pelo topo ou clique no pacote") }
    var packTearAction: String { t("팩 뜯기", "Tear open the pack", "パックを開封",
                                     "Abrir el sobre", "Ouvrir le booster", "Abrir o pacote") }
    var openPack: String { t("뜯기", "Open", "開ける", "Abrir", "Ouvrir", "Abrir") }
    func openPackCount(_ count: Int) -> String {
        guard count > 1 else { return openPack }
        return t("\(count)개 뜯기", "Open \(count)", "\(count)パック開ける",
                 "Abrir \(count)", "Ouvrir \(count)", "Abrir \(count)")
    }
    func packOpenQuantity(_ count: Int) -> String {
        t("개봉 수량 \(count)개", "Open quantity: \(count)", "開封数：\(count)",
          "Cantidad: \(count)", "Quantité : \(count)", "Quantidade: \(count)")
    }
    func packPreparingCount(_ count: Int) -> String {
        t("\(count)팩의 카드를 꺼내는 중…", "Getting \(count) packs ready…",
          "\(count)パックを準備中…", "Preparando \(count) sobres…",
          "Préparation de \(count) boosters…", "Preparando \(count) pacotes…")
    }
    func packBatchOpened(_ count: Int) -> String {
        t("\(count)팩 개봉 결과", "\(count)-pack results", "\(count)パックの開封結果",
          "Resultado de \(count) sobres", "Résultat de \(count) boosters",
          "Resultado de \(count) pacotes")
    }
    func specialPacksFound(_ count: Int) -> String {
        t("특수팩 \(count)개!", "\(count) special pack\(count == 1 ? "" : "s")!",
          "スペシャルパック\(count)個！", "¡\(count) sobres especiales!",
          "\(count) booster\(count == 1 ? "" : "s") spécial\(count == 1 ? "" : "aux") !",
          "\(count) pacote\(count == 1 ? "" : "s") especial\(count == 1 ? "" : "is")!")
    }
    func packBatchSupplement(energy: Int, holoEnergy: Int, code: Int) -> String {
        t("별도 기본 에너지 \(energy)장 (홀로 \(holoEnergy)장) · 코드 \(code)장 · 도감 제외",
          "Plus \(energy) Basic Energy (\(holoEnergy) holo) + \(code) code cards · not in the collection",
          "別枠エネルギー\(energy)枚（ホロ\(holoEnergy)枚）・コード\(code)枚・図鑑対象外",
          "+ \(energy) Energías (\(holoEnergy) holo) + \(code) códigos · fuera de colección",
          "+ \(energy) Énergies (\(holoEnergy) holo) + \(code) codes · hors collection",
          "+ \(energy) Energias (\(holoEnergy) holo) + \(code) códigos · fora da coleção")
    }
    var packOpened: String { t("개봉 결과", "Pack results", "開封結果",
                                 "Resultado", "Résultat", "Resultado") }
    var newCardBadge: String { t("NEW", "NEW", "NEW", "NUEVA", "NOUVEAU", "NOVA") }
    var openAll: String { t("한번에 열기", "Open all", "まとめて開ける",
                             "Abrir todo", "Tout ouvrir", "Abrir tudo") }
    var done: String { t("확인", "Done", "OK", "Listo", "OK", "OK") }
    func packOpenSummary(new: Int, total: Int) -> String {
        t("\(total)장 중 새 카드 \(new)장", "\(new) new of \(total)", "\(total)枚のうち新規 \(new)枚",
           "\(new) nuevas de \(total)", "\(new) nouvelles sur \(total)", "\(new) novas de \(total)")
    }

    // MARK: 컬렉션
    var collectionEmptyHint: String { t("팩을 뜯으면 여기에 모여요.", "Open a pack and they'll show up here.",
                                         "パックを開けるとここに集まります。", "Abre un sobre y aparecerán aquí.",
                                         "Ouvre un booster et elles apparaîtront ici.", "Abra um pacote e elas aparecerão aqui.") }
    var filterSet: String { t("세트", "Set", "セット", "Set", "Set", "Set") }
    var ownedOnly: String { t("보유한 카드만", "Owned only", "所持カードのみ",
                               "Solo en posesión", "Possédées seulement", "Somente possuídas") }
    var tierSummaryToggle: String { t("등급별 수집 현황", "By rarity", "レアリティ別",
                                       "Por rareza", "Par rareté", "Por raridade") }
    var filterTier: String { t("등급", "Rarity", "レアリティ", "Rareza", "Rareté", "Raridade") }
    var notOwnedYet: String { t("아직 없음", "Not owned yet", "未所持",
                                 "Aún no obtenida", "Pas encore obtenue", "Ainda não obtida") }
    var allSets: String { t("전체", "All", "すべて", "Todos", "Tous", "Todos") }
    func collectedOf(_ owned: Int, _ total: Int) -> String { "\(owned) / \(total)" }
    func copiesOwned(_ count: Int) -> String {
        t("\(count)장 보유", "\(count) copies", "\(count)枚所持",
           "\(count) copias", "\(count) exemplaires", "\(count) cópias")
    }

    // MARK: 설정

    var bonusPackNotificationsLabel: String {
        t("보너스 팩 알림", "Bonus pack alerts", "ボーナスパック通知",
           "Avisos de sobre extra", "Alertes de booster bonus", "Avisos de pacote bônus")
    }
    var bonusPackNotificationsHint: String {
        t("사용 한도를 다 채워 팩을 받으면 알려줘요.",
           "Tells you when filling a usage limit earns a pack.",
           "使用上限を使い切ってパックを得たときに知らせます。",
           "Avisa cuando alcanzar un límite te da un sobre.",
           "Prévient quand atteindre une limite donne un booster.",
           "Avisa quando atingir um limite rende um pacote.")
    }
    func bonusPackNotificationBody(window: String, set: String, count: Int) -> String {
        t("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개가 기다립니다.",
           "You maxed the \(window) limit — \(count) \(set) packs are waiting.",
           "\(window) の上限を使い切りました — \(set) パック\(count)つが待っています。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set) te esperan.",
           "Tu as atteint la limite \(window) : \(count) boosters \(set) t'attendent.",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set) esperam.")
    }

    // MARK: 카드 판매

    var sellSpares: String { t("중복 판매", "Sell spares", "重複を売る",
                                "Vender repetidas", "Vendre les doubles", "Vender repetidas") }
    /// 값은 원화로 적는다. 모으는 것은 토큰이지만 카드값이 실제 시세에서 온 값이라,
    /// 파는 자리에서 토큰 자릿수를 보여 주면 얼마를 받는 것인지 가늠이 되지 않는다.
    func sellConfirm(_ count: Int, _ money: String) -> String {
        t("\(count)장을 팔아 \(money)을 받습니다. 한 장은 남습니다.",
           "Sell \(count) for \(money). One copy stays.",
           "\(count)枚を売って \(money)。1枚は残ります。",
           "Vende \(count) por \(money). Se conserva una.",
           "Vends \(count) pour \(money). Un exemplaire reste.",
           "Venda \(count) por \(money). Uma cópia fica.")
    }
    /// 판매가에 도감 추가금이 얹혀 있을 때 그 사실을 적는다.
    func sellBonusIncluded(_ value: Double) -> String {
        let percent = Self.percent(value)
        return t("판매 추가금 +\(percent) 포함", "includes +\(percent) sale bonus",
                  "販売ボーナス +\(percent) 込み", "incluye +\(percent) de bonificación",
                  "bonus de vente +\(percent) inclus", "inclui bônus de venda +\(percent)")
    }
    var sellLowestFinishFirst: String {
        t("가치가 낮은 판형부터 판매됩니다.",
          "Lower-value printings are sold first.",
          "価値の低い仕様から売却されます。",
          "Primero se venden los acabados de menor valor.",
          "Les finitions de moindre valeur sont vendues d'abord.",
          "Os acabamentos de menor valor são vendidos primeiro.")
    }
    func sellDone(_ money: String) -> String {
        t("+\(money)", "+\(money)", "+\(money)", "+\(money)", "+\(money)", "+\(money)")
    }

    // MARK: 사죄의 사료

    func giftTitle(_ kind: WalletStore.Gift.Kind) -> String {
        switch kind {
        case .apology:
            return t("사죄의 사료", "An apology treat", "おわびのごはん",
                      "Un obsequio de disculpa", "Un cadeau d'excuse", "Um agrado de desculpas")
        case .celebration:
            return t("업데이트 기념 사료", "A treat for the update", "アップデート記念のごはん",
                      "Un obsequio por la actualización", "Un cadeau pour la mise à jour",
                      "Um agrado pela atualização")
        }
    }

    /// 무엇이 들어왔는지 숫자로 적는다. 「보상을 드렸습니다」만 있으면 확인하러 탭을 뒤져야 한다.
    /// 팩이 없으면 팩 이야기를 하지 않는다 — 「팩 0개」는 받은 것을 세는 말이 아니다.
    func giftBody(_ kind: WalletStore.Gift.Kind, packs: Int, money: String) -> String {
        switch kind {
        case .apology:
            return t("값이 잘못 보이던 문제로 불편을 드렸어요. 팩 \(packs)개와 \(money)을 넣어 뒀습니다.",
                      "Sorry about the prices showing wrong. \(packs) packs and \(money) are in your wallet.",
                      "価格の表示が誤っていた件、失礼しました。パック \(packs)個と \(money) を入れておきました。",
                      "Perdón por los precios mal mostrados. Te dejamos \(packs) sobres y \(money).",
                      "Désolé pour les prix mal affichés. \(packs) boosters et \(money) t'attendent.",
                      "Desculpe pelos preços exibidos errado. \(packs) pacotes e \(money) estão na carteira.")
        case .celebration:
            return t("업데이트를 기념해 \(money)을 넣어 뒀어요.",
                      "\(money) is in your wallet to mark the new update.",
                      "アップデートを記念して \(money) を入れておきました。",
                      "Te dejamos \(money) para celebrar la actualización.",
                      "\(money) t'attendent pour fêter la mise à jour.",
                      "Deixamos \(money) para comemorar a atualização.")
        }
    }

    // MARK: 한번에 판매

    var bulkSell: String { t("한번에 판매", "Sell in bulk", "まとめて売る",
                              "Vender en lote", "Vendre en lot", "Vender em lote") }
    /// 무엇을 고르는 화면인지 한 줄로. 「중복분만」이 규칙의 핵심이라 여기 적는다.
    var bulkSellPrompt: String { t("중복 카드를 판매할 가격 범위를 골라 주세요.",
                                    "Choose a price range for selling spare cards.",
                                    "重複カードを売る価格範囲を選んでください。",
                                    "Elige un rango de precios para vender repetidas.",
                                    "Choisissez une gamme de prix pour vendre les doubles.",
                                    "Escolha uma faixa de preços para vender repetidas.") }
    var bulkSellAllPrices: String { t("전체 범위", "All prices", "価格制限なし",
                                       "Todos los precios", "Tous les prix", "Todos os preços") }
    var bulkSellAllPricesHint: String { t("현재 필터 안의 중복 카드를 가격 제한 없이 판매",
        "Sell spare cards in the current filter without a price limit",
        "現在のフィルター内の重複カードを価格制限なしで売る",
        "Vender repetidas del filtro actual sin límite de precio",
        "Vendre les doubles du filtre actuel sans limite de prix",
        "Vender repetidas do filtro atual sem limite de preço") }
    /// 임계값 칩. "1,000원 이하" 처럼 읽힌다.
    func bulkSellUpTo(_ money: String) -> String {
        t("\(money) 이하", "up to \(money)", "\(money) 以下",
           "hasta \(money)", "jusqu'à \(money)", "até \(money)")
    }
    /// 팔릴 것의 요약.
    func bulkSellSummary(_ kinds: Int, _ copies: Int, _ money: String) -> String {
        t("\(kinds)종 · \(copies)장 · +\(money)",
           "\(kinds) kinds · \(copies) cards · +\(money)",
           "\(kinds)種 · \(copies)枚 · +\(money)",
           "\(kinds) tipos · \(copies) cartas · +\(money)",
           "\(kinds) types · \(copies) cartes · +\(money)",
           "\(kinds) tipos · \(copies) cartas · +\(money)")
    }
    var bulkSellNothing: String { t("팔 중복이 없어요", "No spares to sell", "売る重複がありません",
                                     "No hay repetidas", "Aucun double", "Nenhuma repetida") }
    /// 되돌릴 수 없다는 것을 확인 앞에 적는다.
    var bulkSellConfirm: String { t("한 종류에 한 장씩은 남습니다. 되돌릴 수 없어요.",
                                     "One copy of each stays. This can't be undone.",
                                     "各1枚は残ります。取り消せません。",
                                     "Se conserva una de cada. No se puede deshacer.",
                                     "Un exemplaire de chaque reste. Irréversible.",
                                     "Uma cópia de cada fica. Não pode ser desfeito.") }
    func bulkSellDone(_ copies: Int, _ money: String) -> String {
        t("\(copies)장을 팔아 \(money)을 받았어요",
           "Sold \(copies) cards for \(money)",
           "\(copies)枚を売って \(money)",
           "Vendiste \(copies) cartas por \(money)",
           "\(copies) cartes vendues pour \(money)",
           "Vendeu \(copies) cartas por \(money)")
    }

    // MARK: 등급

    /// 등급 배지 — 국내 커뮤니티가 쓰는 약칭을 그대로 쓴다. 카드에 인쇄된 표기라 언어와 무관하다.
    func tierBadge(_ tier: CardTier) -> String { tier.rawValue }

    /// 등급 전체 이름. 배지만으로는 처음 보는 사용자가 뜻을 모르므로 상세에서 함께 보여준다.
    func tierName(_ tier: CardTier) -> String {
        switch tier {
        case .energy:         return t("에너지", "Energy", "エネルギー", "Energía", "Énergie", "Energia")
        case .common:         return t("커먼", "Common", "コモン", "Común", "Commune", "Comum")
        case .uncommon:       return t("언커먼", "Uncommon", "アンコモン", "Poco común", "Peu commune", "Incomum")
        case .rare:           return t("레어", "Rare", "レア", "Rara", "Rare", "Rara")
        case .doubleRare:     return t("더블레어", "Double Rare", "ダブルレア", "Doble rara", "Double rare", "Dupla rara")
        case .promo:          return t("프로모", "Promo", "プロモ", "Promo", "Promo", "Promo")
        case .tripleRare:     return t("트리플레어", "Triple Rare", "トリプルレア", "Triple rara", "Triple rare", "Tripla rara")
        case .prismStar:      return t("프리즘스타", "Prism Star", "プリズムスター", "Prisma", "Prisme", "Prisma")
        case .amazing:        return t("어메이징레어", "Amazing Rare", "オーロラレア", "Asombrosa", "Incroyable", "Incrível")
        case .radiant:        return t("찬란한", "Radiant", "かがやく", "Radiante", "Radieux", "Radiante")
        case .characterRare:  return t("캐릭터레어", "Character Rare", "キャラクターレア",
                                        "Personaje rara", "Personnage rare", "Personagem rara")
        case .artRare:        return t("아트레어", "Art Rare", "アートレア", "Arte rara", "Art rare", "Arte rara")
        case .aceSpec:        return t("에이스 스펙", "ACE SPEC", "ACE SPEC", "ACE SPEC", "ACE SPEC", "ACE SPEC")
        case .superRare:      return t("슈퍼레어", "Super Rare", "スーパーレア", "Súper rara", "Super rare", "Super rara")
        case .shiny:          return t("샤이니", "Shiny", "色違い", "Variocolor", "Chromatique", "Brilhante")
        case .shinyUltra:     return t("샤이니 울트라레어", "Shiny Ultra Rare", "色違いウルトラレア",
                                        "Variocolor ultra", "Chromatique ultra", "Brilhante ultra")
        case .specialArtRare: return t("스페셜아트레어", "Special Art Rare", "スペシャルアートレア",
                                        "Arte especial rara", "Art spécial rare", "Arte especial rara")
        case .shining:        return t("빛나는", "Shining", "ひかる", "Brillante", "Brillant", "Brilhante")
        case .hyperRare:      return t("하이퍼레어", "Hyper Rare", "ハイパーレア", "Híper rara", "Hyper rare", "Hiper rara")
        case .ultraRare:      return t("울트라레어", "Ultra Rare", "ウルトラレア", "Ultra rara", "Ultra rare", "Ultra rara")
        case .blackWhiteRare: return t("블랙화이트레어", "Black White Rare", "ブラックホワイトレア",
                                        "Black White Rare", "Black White Rare", "Black White Rare")
        case .megaAttack:     return t("메가어택레어", "Mega Attack Rare", "メガアタックレア",
                                        "Mega Attack Rare", "Mega Attack Rare", "Mega Attack Rare")
        case .megaUltraRare:  return t("메가울트라레어", "Mega Ultra Rare", "メガウルトラレア",
                                        "Mega Ultra Rare", "Mega Ultra Rare", "Mega Ultra Rare")
        case .futureUltra:    return t("퓨처울트라레어", "Future Ultra Rare", "フューチャーウルトラレア",
                                        "Future Ultra Rare", "Future Ultra Rare", "Future Ultra Rare")
        }
    }

    // MARK: 보너스 팩 알림
    var bonusPackTitle: String { t("보너스 팩 도착!", "Bonus pack!", "ボーナスパック！",
                                    "¡Sobre extra!", "Booster bonus !", "Pacote bônus!") }
    func bonusPackBody(window: String, set: String, count: Int) -> String {
        t("\(window) 한도를 다 채웠어요 — \(set) 팩 \(count)개를 받았어요.",
           "You maxed the \(window) limit — \(count) \(set) packs.",
           "\(window) の上限を使い切りました — \(set) パックを\(count)つ獲得。",
           "Alcanzaste el límite de \(window): \(count) sobres de \(set).",
           "Tu as atteint la limite \(window) : \(count) boosters \(set).",
           "Você atingiu o limite de \(window): \(count) pacotes de \(set).")
    }

    // MARK: 오류
    var cardIndexMissing: String { t("카드 목록을 불러올 수 없어요.", "Couldn't load the card list.",
                                      "カードリストを読み込めません。", "No se pudo cargar la lista de cartas.",
                                      "Impossible de charger la liste des cartes.", "Não foi possível carregar a lista de cartas.") }

    /// 시대에 든 세트 수. 「18개」처럼 읽힌다.
    func shopPackCount(_ count: Int) -> String {
        t("\(count)개", "\(count)", "\(count)個", "\(count)", "\(count)", "\(count)")
    }
    var shopPacksSection: String { t("일반 팩", "Packs", "通常パック",
                                      "Sobres", "Boosters", "Pacotes") }

    // MARK: 오리파
    var oripaTitle: String { t("오리파", "Oripa", "オリパ", "Oripa", "Oripa", "Oripa") }
    /// 공지 보드에서 이미 나간 카드에 얹는 표시. **흑백으로만 두면 「미보유」로 읽힌다** —
    /// 컬렉션이 미보유를 그렇게 그리므로 나갔다는 것은 글자로 적는다.
    var oripaDrawnMark: String { t("뽑음", "Pulled", "済", "Sacada", "Tirée", "Tirada") }
    /// 어느 봉투에 들어 있(었)는지. 대응이 미리 굳어 있었다는 흔적이다.
    func oripaCardInEnvelope(_ number: Int, _ name: String) -> String {
        t("\(number)번 봉투 · \(name)", "Envelope #\(number) · \(name)",
           "\(number)番の封 · \(name)", "Sobre n.º \(number) · \(name)",
           "Pochette n° \(number) · \(name)", "Envelope nº \(number) · \(name)")
    }
    var oripaDrawHint: String { t("밀어서 확인", "Slide to reveal", "スライドして確認",
                                  "Desliza para ver", "Fais glisser pour voir",
                                  "Deslize para ver") }
    /// 마지막 장에서 요약으로 넘어가는 버튼.
    var packSeeResult: String { t("결과 보기", "See results", "結果を見る",
                                   "Ver resultados", "Voir les résultats", "Ver resultados") }
    var oripaSeeDetail: String { t("자세히 보기", "See details", "詳しく見る",
                                    "Ver detalles", "Voir la carte", "Ver detalhes") }
    var oripaPull: String { t("뽑기", "Pull", "引く", "Tirar", "Tirer", "Tirar") }
    /// 공지 보드에서 뽑기 창으로 들어가는 버튼. **여기서 바로 뽑지 않는다** —
    /// 무엇이 걸려 있는지 본 다음 봉투를 고르는 것이 순서다.
    var oripaGoPull: String { t("뽑으러 가기", "Go pull", "引きに行く",
                                 "Ir a tirar", "Aller tirer", "Ir tirar") }
    /// 봉투를 아직 안 골랐을 때 뽑기 줄에 적는 말.
    var oripaPickHint: String { t("봉투를 골라 주세요", "Pick an envelope", "封を選んでください",
                                   "Elige un sobre", "Choisis une pochette", "Escolha um envelope") }
    func oripaPicked(_ number: Int) -> String {
        t("\(number)번 봉투", "Envelope #\(number)", "\(number)番の封",
           "Sobre n.º \(number)", "Pochette n° \(number)", "Envelope nº \(number)")
    }
    func oripaRemaining(_ left: Int, _ total: Int) -> String {
        t("남은 봉투 \(left) / \(total)", "\(left) of \(total) left", "残り \(left) / \(total)",
           "\(left) de \(total) sobres", "\(left) sur \(total) restantes", "\(left) de \(total) restantes")
    }
    func oripaBoxNumber(_ serial: Int) -> String {
        t("\(serial)번 박스", "Box #\(serial)", "\(serial)番の箱",
           "Caja n.º \(serial)", "Boîte n° \(serial)", "Caixa nº \(serial)")
    }
    var oripaReplace: String { t("새 박스로", "New box", "新しい箱に",
                                  "Caja nueva", "Nouvelle boîte", "Caixa nova") }
    /// 확인 문구는 한 줄을 넘기지 않는다. 버튼이 「새 박스로 / 취소」라 질문은 짧아도 통하고,
    /// 길면 줄바꿈이 생겨 확인을 누를 때마다 화면이 덜컹거린다. 자세한 설명은 툴팁에 둔다.
    var oripaReplaceConfirm: String { t("버릴까요?", "Discard?", "捨てますか？",
                                         "¿Descartar?", "Jeter ?", "Descartar?") }
    var oripaReplaceHelp: String { t("지금 박스를 버리고 새 박스를 받아요. 값은 들지 않아요.",
                                      "Discard this box for a fresh one. It costs nothing.",
                                      "今の箱を捨てて新しい箱を受け取ります。無料です。",
                                      "Descarta esta caja por una nueva. Es gratis.",
                                      "Remplace cette boîte par une neuve. C'est gratuit.",
                                      "Troca esta caixa por uma nova. É grátis.") }
    func oripaOwnedCount(_ count: Int) -> String {
        t("이미 가진 카드 \(count)장", "\(count) you already own", "所持済み \(count)枚",
           "\(count) que ya tienes", "\(count) déjà possédées", "\(count) que você já tem")
    }
    var oripaRefilled: String { t("박스를 다 비웠어요. 새 박스가 들어왔습니다.",
                                   "You cleared the box. A fresh one is in.",
                                   "箱を空にしました。新しい箱が入りました。",
                                   "Vaciaste la caja. Ha llegado una nueva.",
                                   "Tu as vidé la boîte. Une nouvelle est arrivée.",
                                   "Você esvaziou a caixa. Chegou uma nova.") }

    // MARK: 갓팩
    var godPackTitle: String { t("갓팩!", "God Pack!", "神引き！", "¡Sobre dorado!",
                                  "Booster divin !", "Pacote divino!") }
    var godPackHint: String { t("이 팩은 전부 레어 이상이에요.", "Every card in this pack is rare or better.",
                                 "このパックは全てレア以上です。", "Todas las cartas son raras o mejores.",
                                 "Toutes les cartes sont rares ou mieux.", "Todas as cartas são raras ou melhores.") }
    var godPackBadge: String { t("갓팩", "God Pack", "神引き", "Dorado", "Divin", "Divino") }
    var godPackPreviewButton: String {
        t("갓팩 연출 테스트", "Test God Pack", "神パック演出テスト", "Probar God Pack",
          "Tester le God Pack", "Testar God Pack")
    }
    var godPackPreviewHelp: String {
        t("팩과 재화를 쓰지 않고 실제 갓팩 구성으로 연출만 확인해요.",
          "Preview the real God Pack composition without consuming packs or currency.",
          "パックや通貨を消費せず、実際の神パック構成で演出だけ確認します。",
          "Previsualiza la composición real sin gastar sobres ni moneda.",
          "Prévisualise la vraie composition sans consommer de booster ni de monnaie.",
          "Pré-visualiza a composição real sem gastar pacotes ou moeda.")
    }
    var godPackPreviewNotice: String {
        t("연출 테스트 · 팩 차감 및 카드 지급 없음",
          "Effect preview · no pack consumed or cards granted",
          "演出テスト・パック消費／カード付与なし",
          "Vista previa · no consume sobre ni entrega cartas",
          "Aperçu · aucun booster consommé, aucune carte ajoutée",
          "Prévia · nenhum pacote consumido ou carta concedida")
    }

    func specialPackTitle(_ variant: PackVariant) -> String {
        switch variant {
        case .prismaticEvolutionsDemigod: return prismaticDemiTitle
        case .scarletViolet151Demigod:
            return t("진화라인 특수팩!", "Evolution-line special pack!", "進化ライン特別パック！",
                     "¡Sobre especial de evolución!", "Booster spécial évolution !",
                     "Pacote especial de evolução!")
        case .prismaticEvolutionsGod:
            return godPackTitle
        case .blackBoltWhiteFlareGod:
            return godPackTitle
        case .ascendedHeroesGod:
            return godPackTitle
        case .standard, .celebrations:
            return packOpened
        }
    }

    func specialPackHint(_ variant: PackVariant) -> String {
        switch variant {
        case .prismaticEvolutionsDemigod: return prismaticDemiHint
        case .scarletViolet151Demigod:
            return t("스타팅 포켓몬 한 계열의 AR 2장과 SAR 1장이 함께 들어 있어요.",
                     "One starter evolution line appears together: two IRs and one SIR.",
                     "御三家1系統のAR2枚とSAR1枚が一緒に入っています。",
                     "Una línea inicial completa: dos IR y una SIR.",
                     "Une lignée de starter complète : deux IR et une SIR.",
                     "Uma linha inicial completa: duas IR e uma SIR.")
        case .prismaticEvolutionsGod:
            return t("마스터볼 이브이와 이브이 진화형 SIR 9장이 들어 있어요.",
                     "Master Ball Eevee plus all nine Eeveelution SIR cards.",
                     "マスターボール柄イーブイと進化形SIR9枚入りです。",
                     "Eevee Master Ball y las nueve SIR de sus evoluciones.",
                     "Évoli Master Ball et les neuf SIR de ses évolutions.",
                     "Eevee Master Ball e as nove SIR de suas evoluções.")
        case .blackBoltWhiteFlareGod:
            return t("일러스트레이션 레어 9장과 스페셜 일러스트레이션 레어 1장이 들어 있어요.",
                     "Nine Illustration Rares plus one Special Illustration Rare.",
                     "イラストレア9枚とスペシャルイラストレア1枚入りです。",
                     "Nueve cartas de Ilustración Rara y una Ilustración Especial Rara.",
                     "Neuf Illustration Rares et une Illustration Spéciale Rare.",
                     "Nove Raras de Ilustração e uma Rara de Ilustração Especial.")
        case .ascendedHeroesGod:
            return t("메가어택 레어 3장과 스페셜 일러스트레이션 레어 7장이 들어 있어요.",
                     "Three Mega Attack Rares plus seven Special Illustration Rares.",
                     "メガアタックレア3枚とスペシャルアートレア7枚入りです。",
                     "Tres Mega Attack Rares y siete Special Illustration Rares.",
                     "Trois Mega Attack Rares et sept Special Illustration Rares.",
                     "Três Mega Attack Rares e sete Special Illustration Rares.")
        case .standard, .celebrations:
            return ""
        }
    }

    func specialPackBadge(_ variant: PackVariant) -> String {
        switch variant {
        case .prismaticEvolutionsDemigod: return prismaticDemiTitle
        case .scarletViolet151Demigod:
            return t("151 특수팩", "151 Special", "151特別", "Especial 151", "Spécial 151", "Especial 151")
        case .prismaticEvolutionsGod:
            return godPackBadge
        case .blackBoltWhiteFlareGod:
            return godPackBadge
        case .ascendedHeroesGod:
            return godPackBadge
        case .standard, .celebrations:
            return ""
        }
    }

    func specialPackEstimate(_ rule: PackSpecialVariantRule) -> String {
        let odds = rule.estimatedSimulatorOneIn
        switch rule.variant {
        case .prismaticEvolutionsDemigod:
            return "\(prismaticDemiTitle) · 1/\(odds) · \(estimatedRate)"
        case .scarletViolet151Demigod:
            return t("151 진화라인 특수팩 · 시뮬레이터 설정 약 1/\(odds) (공식 확률 아님)",
                     "151 evolution-line pack · simulator setting ~1/\(odds) (not an official rate)",
                     "151進化ライン特別パック・シミュレーター設定 約1/\(odds)（公式確率ではありません）",
                     "Sobre de evolución 151 · ajuste ~1/\(odds) (no es una tasa oficial)",
                     "Booster évolution 151 · réglage ~1/\(odds) (taux non officiel)",
                     "Pacote de evolução 151 · ajuste ~1/\(odds) (taxa não oficial)")
        case .prismaticEvolutionsGod:
            return t("프리즈마틱 갓팩 · 시뮬레이터 설정 약 1/\(odds) (공식 확률 아님)",
                     "Prismatic God Pack · simulator setting ~1/\(odds) (not an official rate)",
                     "プリズマティック神パック・シミュレーター設定 約1/\(odds)（公式確率ではありません）",
                     "God Pack Prismático · ajuste ~1/\(odds) (no es una tasa oficial)",
                     "God Pack Prismatique · réglage ~1/\(odds) (taux non officiel)",
                     "God Pack Prismático · ajuste ~1/\(odds) (taxa não oficial)")
        case .blackBoltWhiteFlareGod:
            return t("블랙 보트·화이트 플레어 갓팩 · 시뮬레이터 설정 약 1/\(odds) (공식 확률 아님)",
                     "Black Bolt / White Flare God Pack · simulator setting ~1/\(odds) (not an official rate)",
                     "ブラックボルト・ホワイトフレア神パック・シミュレーター設定 約1/\(odds)（公式確率ではありません）",
                     "God Pack de Black Bolt / White Flare · ajuste ~1/\(odds) (no es una tasa oficial)",
                     "God Pack Black Bolt / White Flare · réglage ~1/\(odds) (taux non officiel)",
                     "God Pack Black Bolt / White Flare · ajuste ~1/\(odds) (taxa não oficial)")
        case .ascendedHeroesGod:
            return t("어센디드 히어로즈 갓팩 · 시뮬레이터 설정 약 1/\(odds) (공식 확률 아님)",
                     "Ascended Heroes God Pack · simulator setting ~1/\(odds) (not an official rate)",
                     "アセンデッドヒーローズ神パック・シミュレーター設定 約1/\(odds)（公式確率ではありません）",
                     "God Pack de Ascended Heroes · ajuste ~1/\(odds) (no es una tasa oficial)",
                     "God Pack Ascended Heroes · réglage ~1/\(odds) (taux non officiel)",
                     "God Pack Ascended Heroes · ajuste ~1/\(odds) (taxa não oficial)")
        case .standard, .celebrations:
            return ""
        }
    }

    // MARK: 조합 도감
    var dexTab: String { t("도감", "Dex", "図鑑", "Dex", "Dex", "Dex") }
    var dexComplete: String { t("완성", "Complete", "コンプリート", "Completo", "Complet", "Completo") }
    var dexClaim: String { t("보상 수령", "Claim reward", "報酬を受け取る",
                              "Reclamar", "Récupérer", "Resgatar") }
    var dexClaimed: String { t("수령 완료", "Claimed", "受取済み", "Reclamado", "Récupéré", "Resgatado") }
    var dexPerksNone: String { t("아직 없음", "None yet", "まだなし", "Ninguna", "Aucun", "Nenhum") }
    var dexGoBuyPack: String { t("이 팩 사러 가기", "Buy this pack", "このパックを買う",
                                  "Comprar este sobre", "Acheter ce booster", "Comprar este pacote") }
    var dexReward: String { t("완성 보상", "Reward", "完成報酬", "Recompensa", "Récompense", "Recompensa") }
    // MARK: 도감 개편 — 갈래·마일스톤·새 보상 통로
    var dexThemeSection: String { t("조합", "Combos", "組み合わせ", "Combos", "Combos", "Combos") }
    var dexSetSection: String { t("세트", "Sets", "セット", "Sets", "Sets", "Sets") }
    var dexCardSearchPlaceholder: String { t("카드 이름 검색", "Search card names", "カード名を検索",
                                              "Buscar cartas", "Rechercher une carte", "Buscar cartas") }
    var dexCardSearchLabel: String { t("도감 카드 이름 검색", "Search dex by card name", "図鑑をカード名で検索",
                                       "Buscar en el dex por carta", "Rechercher dans le dex par carte",
                                       "Buscar no dex por carta") }
    var dexCardSearchClear: String { t("검색어 지우기", "Clear search", "検索を消去",
                                       "Borrar búsqueda", "Effacer la recherche", "Limpar busca") }
    func dexCardSearchEmpty(_ query: String) -> String {
        t("‘\(query)’ 카드가 들어간 도감이 없어요.", "No dex contains a card matching ‘\(query)’.",
          "「\(query)」に一致するカードを含む図鑑はありません。",
          "Ningún dex contiene una carta que coincida con ‘\(query)’.",
          "Aucun dex ne contient de carte correspondant à « \(query) ».",
          "Nenhum dex contém uma carta correspondente a ‘\(query)’.")
    }
    func dexCardSearchMatches(_ names: [String]) -> String {
        let joined = names.joined(separator: ", ")
        return t("일치 카드: \(joined)", "Matching cards: \(joined)", "一致カード：\(joined)",
                 "Cartas coincidentes: \(joined)", "Cartes correspondantes : \(joined)",
                 "Cartas correspondentes: \(joined)")
    }
    /// 세트 도감의 목표 — 그 세트의 **종**을 몇 할까지 모으는가.
    func dexMilestone(_ percent: Int) -> String {
        t("\(percent)% 수집", "\(percent)% collected", "\(percent)% 収集",
           "\(percent)% reunido", "\(percent)% réuni", "\(percent)% reunido")
    }
    func dexMilestoneNeed(_ need: Int, _ total: Int) -> String {
        t("\(need)종 / \(total)종", "\(need) of \(total)", "\(need)種 / \(total)種",
           "\(need) de \(total)", "\(need) sur \(total)", "\(need) de \(total)")
    }
    /// 팩 할인 쿠폰. **세트가 정해져 있다** — 아껴 둘 이유가 없어야 한다.
    func dexRewardCoupon(_ setName: String, _ percent: Int, _ count: Int) -> String {
        t("\(setName) 팩 \(percent)% 쿠폰 \(count)장",
           "\(count)× \(percent)% off \(setName) packs",
           "\(setName) パック \(percent)% クーポン \(count)枚",
           "\(count) cupones \(percent)% \(setName)",
           "\(count) bons \(percent)% \(setName)",
           "\(count) cupons \(percent)% \(setName)")
    }
    var dexCouponHelp: String { t("그 세트 팩을 살 때 한 장씩 쓰여요. 상점에 할인가가 표시됩니다.",
                                   "Spent one per pack of that set. The shop shows the cut price.",
                                   "そのセットのパックを買うと1枚使われます。店に割引価格が出ます。",
                                   "Se gasta uno por sobre de ese set. La tienda muestra el precio rebajado.",
                                   "Un bon par booster de ce set. La boutique affiche le prix réduit.",
                                   "Um por pacote desse set. A loja mostra o preço com desconto.") }
    /// 상점의 쿠폰함 갈래. **늘 자리를 지킨다** — 칸이 폭을 나눠 가지므로 갈래가 생겼다
    /// 사라지면 옆 칸의 폭과 자리가 함께 움직인다. 장수는 있을 때만 덧붙인다.
    func shopCouponsSection(_ count: Int) -> String {
        guard count > 0 else {
            return t("쿠폰", "Coupons", "クーポン", "Cupones", "Bons", "Cupons")
        }
        return t("쿠폰 \(count)", "Coupons \(count)", "クーポン \(count)",
                  "Cupones \(count)", "Bons \(count)", "Cupons \(count)")
    }
    var couponBoxEmpty: String { t("아직 쿠폰이 없어요.", "No coupons yet.", "クーポンはまだありません。",
                                    "Aún no tienes cupones.", "Pas encore de bons.",
                                    "Ainda sem cupons.") }
    /// 쿠폰함 한 줄 — 어느 세트 팩을 얼마에 살 수 있는가.
    func couponRowDiscount(_ percent: Int) -> String {
        t("\(percent)% 할인", "\(percent)% off", "\(percent)% 割引",
           "\(percent)% dto.", "\(percent)% de remise", "\(percent)% off")
    }
    var couponBoxHint: String { t("도감을 완성하면 그 세트 팩 쿠폰이 들어와요.",
                                   "Completing a dex hands you coupons for that set's packs.",
                                   "図鑑をコンプリートすると、そのセットのクーポンが入ります。",
                                   "Completar un dex te da cupones de ese set.",
                                   "Compléter un dex donne des bons pour ce set.",
                                   "Completar um dex dá cupons desse set.") }

    /// 상점에 적는 쿠폰 잔량.
    func packCouponsLeft(_ count: Int) -> String {
        t("쿠폰 \(count)장", "\(count) coupons", "クーポン \(count)枚",
           "\(count) cupones", "\(count) bons", "\(count) cupons")
    }
    /// 확정 카드 한 장. 등급 하한은 표시용이고 실제 선택은 값이 한다.
    func dexRewardCard(_ tier: String) -> String {
        t("\(tier) 이상 카드 1장", "One \(tier) or better", "\(tier)以上 1枚",
           "1 carta \(tier)+", "1 carte \(tier)+", "1 carta \(tier)+")
    }
    var dexRewardCardHelp: String { t("아직 없는 카드 중에서 값이 맞는 한 장을 드려요.",
                                       "A card you do not own yet, matched by value.",
                                       "未所持のカードから、値に合う1枚を差し上げます。",
                                       "Una carta que no tienes, elegida por valor.",
                                       "Une carte qui te manque, choisie par valeur.",
                                       "Uma carta que falta, escolhida por valor.") }
    var titleSectionLabel: String { t("칭호", "Title", "称号", "Título", "Titre", "Título") }
    var titleNone: String { t("없음", "None", "なし", "Ninguno", "Aucun", "Nenhum") }
    /// 완성 수 계단 — 도감을 몇 개 완성했는가로 영구 혜택이 열린다.
    func dexLadderNext(_ done: Int, _ need: Int) -> String {
        t("완성 \(done) / \(need) — 다음 혜택까지", "\(done) of \(need) to the next perk",
           "コンプリート \(done) / \(need) — 次のボーナスまで",
           "\(done) de \(need) para la próxima ventaja",
           "\(done) sur \(need) avant le prochain bonus",
           "\(done) de \(need) até o próximo bônus")
    }
    var dexLadderDone: String { t("계단을 다 올랐어요.", "You topped out the ladder.",
                                   "階段を上りきりました。", "Has subido toda la escalera.",
                                   "Tu as gravi toute l'échelle.", "Você subiu tudo.") }

    var dexPerksHeader: String { t("누적 혜택", "Perks", "累積ボーナス", "Ventajas", "Bonus", "Bônus") }
    var dexCompletedBanner: String { t("도감 완성!", "Dex complete!", "図鑑コンプリート！",
                                        "¡Dex completo!", "Dex complété !", "Dex completo!") }
    var dexCardBelongsTo: String { t("이 카드가 들어가는 도감", "Dexes using this card",
                                      "このカードが入る図鑑", "Dexes con esta carta",
                                      "Dex avec cette carte", "Dexes com esta carta") }
    var dexEmpty: String { t("도감 목록을 불러올 수 없어요.", "Couldn't load the dex list.",
                              "図鑑リストを読み込めません。", "No se pudo cargar la lista de dex.",
                              "Impossible de charger la liste des dex.", "Não foi possível carregar a lista.") }

    func dexProgress(_ owned: Int, _ total: Int) -> String { "\(owned) / \(total)" }

    func dexCountSummary(_ done: Int, _ total: Int) -> String {
        t("완성 \(done) / \(total)", "\(done) of \(total) complete", "\(total) 中 \(done) 完成",
           "\(done) de \(total) completos", "\(done) sur \(total) complétés", "\(done) de \(total) completos")
    }

    func dexRewardPacks(_ count: Int) -> String {
        t("팩 \(count)개", "\(count) packs", "パック \(count)個",
           "\(count) sobres", "\(count) boosters", "\(count) pacotes")
    }
    /// 어느 세트 팩을 받는지는 개수만으로는 알 수 없다.
    func dexRewardPacksHelp(_ count: Int, _ setName: String) -> String {
        t("\(setName) 팩 \(count)개를 받아요.",
           "You get \(count) \(setName) packs.",
           "\(setName) パックを \(count)個もらえます。",
           "Recibes \(count) sobres de \(setName).",
           "Tu reçois \(count) boosters \(setName).",
           "Você recebe \(count) pacotes de \(setName).")
    }

    /// 한 팩에서 이 카드가 나올 확률. 없는 카드를 눌렀을 때 보여준다 —
    /// 얼마나 먼 카드인지 알아야 계속 살지 판단할 수 있다.
    func dexPullChance(_ percent: String) -> String {
        t("한 팩에서 \(percent)", "\(percent) per pack", "1パックあたり \(percent)",
           "\(percent) por sobre", "\(percent) par booster", "\(percent) por pacote")
    }

    /// 혜택 한 줄. 종류 이름과 부호 붙은 값을 함께 적는다.
    func dexPerkText(_ perk: DexPerk) -> String {
        switch perk.kind {
        case .tokenGain:    return "\(dexPerkTokenGain) +\(Self.percent(perk.value))"
        case .packDiscount: return "\(dexPerkPackDiscount) −\(Self.percent(perk.value))"
        case .dustBonus:    return "\(dexPerkDustBonus) +\(Self.percent(perk.value))"
        case .hitOdds:      return "\(dexPerkHitOdds) +\(Self.percent(perk.value))"
        }
    }

    /// 누적 혜택 한 항목. 0 이면 nil — 화면이 그 칸을 아예 만들지 않게 한다.
    func dexPerkSummaryItem(_ kind: DexPerkKind, _ perks: DexPerks) -> String? {
        switch kind {
        case .tokenGain:
            return perks.tokenGain > 0 ? "\(dexPerkTokenGain) +\(Self.percent(perks.tokenGain))" : nil
        case .packDiscount:
            return perks.packDiscount > 0 ? "\(dexPerkPackDiscount) −\(Self.percent(perks.packDiscount))" : nil
        case .dustBonus:
            return perks.dustBonus > 0 ? "\(dexPerkDustBonus) +\(Self.percent(perks.dustBonus))" : nil
        case .hitOdds:
            return perks.hitOdds > 0 ? "\(dexPerkHitOdds) +\(Self.percent(perks.hitOdds))" : nil
        }
    }

    var dexPerkTokenGain: String { t("적립 토큰", "Token earning", "獲得トークン",
                                      "Tokens ganados", "Tokens gagnés", "Tokens ganhos") }
    var dexPerkPackDiscount: String { t("팩 가격", "Pack price", "パック価格", "Precio", "Prix", "Preço") }
    var dexPerkDustBonus: String { t("판매 추가금", "Sale bonus", "販売ボーナス",
                                      "Bonificación de venta", "Bonus de vente", "Bônus de venda") }
    var dexPerkHitOdds: String { t("상위 등급 확률", "Higher rarity odds", "上位レア確率",
                                    "Prob. de rareza alta", "Chance de haute rareté",
                                    "Chance de raridade alta") }

    /// 혜택이 실제로 무엇을 바꾸는지 한 줄로. 이름 위에 마우스를 올리면 뜬다.
    func dexPerkHelp(_ kind: DexPerkKind) -> String {
        switch kind {
        case .tokenGain:
            return t("코딩으로 쌓이는 토큰을 그만큼 더 받아요.",
                      "You earn that much more from the tokens you burn while coding.",
                      "コーディングで貯まるトークンをその分多く受け取れます。",
                      "Ganas ese porcentaje extra de tokens al programar.",
                      "Tu gagnes ce pourcentage de tokens en plus en codant.",
                      "Você ganha essa porcentagem extra de tokens ao programar.")
        case .packDiscount:
            return t("모든 팩을 그만큼 싸게 살 수 있어요.",
                      "Every pack costs that much less.",
                      "すべてのパックがその分安くなります。",
                      "Todos los sobres cuestan menos.",
                      "Tous les boosters coûtent moins cher.",
                      "Todos os pacotes ficam mais baratos.")
        case .dustBonus:
            return t("중복 카드를 팔 때 시세보다 그만큼 더 받아요.",
                      "Selling duplicates pays that much above market price.",
                      "重複カードを売るとき相場よりその分多くもらえます。",
                      "Vender duplicados paga ese porcentaje por encima del precio.",
                      "Vendre les doublons rapporte ce pourcentage au-dessus du marché.",
                      "Vender duplicatas paga essa porcentagem acima do mercado.")
        case .hitOdds:
            return t("팩마다 하나씩 들어오는 레어 이상 자리에서 더 높은 등급이 나올 확률이 올라가요.",
                      "The guaranteed rare slot rolls higher rarities more often.",
                      "パックごとの確定レア枠で上位レアが出やすくなります。",
                      "La carta rara garantizada sale con más rareza.",
                      "La carte rare garantie monte plus souvent en rareté.",
                      "A carta rara garantida sobe de raridade com mais frequência.")
        }
    }

    /// 0.005 → "0.5%". 소수점은 필요할 때만 쓴다.
    private static func percent(_ value: Double) -> String {
        let scaled = value * 100
        return scaled == scaled.rounded() ? "\(Int(scaled))%" : String(format: "%.1f%%", scaled)
    }
}
