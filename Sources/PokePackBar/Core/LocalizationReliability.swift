import Foundation

extension L {
    var sealedMarket: String { t("밀봉 시장가", "Sealed market", "未開封相場", "Mercado sellado", "Marché scellé", "Mercado lacrado") }
    var economyFloor: String { t("게임 하한", "Game floor", "ゲーム下限", "Mínimo del juego", "Plancher du jeu", "Mínimo do jogo") }
    func supplement(_ value: PackSupplement) -> String {
        let foil = value.holoEnergy ? "Holo" : "Non-foil"
        return t("별도 기본 에너지 \(value.energyCount)장 (\(foil)) · 코드 \(value.codeCount)장 · 도감 제외",
                 "Plus \(value.energyCount) Basic Energy (\(foil)) + \(value.codeCount) code · not in the collection",
                 "別枠エネルギー\(value.energyCount)枚 (\(foil))・コード\(value.codeCount)枚・図鑑対象外",
                 "+ \(value.energyCount) Energía (\(foil)) + \(value.codeCount) código · fuera de colección",
                 "+ \(value.energyCount) Énergie (\(foil)) + \(value.codeCount) code · hors collection",
                 "+ \(value.energyCount) Energia (\(foil)) + \(value.codeCount) código · fora da coleção")
    }
    var prismaticDemiTitle: String { t("프리즈마틱 3 SIR 특수팩", "Prismatic 3 SIR pack", "プリズマティック3 SIR", "Prismatic 3 SIR", "Prismatic 3 SIR", "Prismatic 3 SIR") }
    var prismaticDemiHint: String { t("역홀로 두 칸과 레어 칸에 SIR 3장이 들어 있어요.", "Three SIRs replace the two reverse positions and rare position.", "リバース2枠とレア枠がSIR3枚になります。", "Tres SIR sustituyen las dos inversas y la rara.", "Trois SIR remplacent les deux reverses et la rare.", "Três SIR substituem as duas reversas e a rara.") }
    var estimatedRate: String { t("추정 설정 · 공식 확률 아님", "Simulator estimate, not official odds", "推定設定・公式確率ではありません", "Estimación, no oficial", "Estimation, non officielle", "Estimativa, não oficial") }
    var saveFailed: String { t("저장 실패 · 변경을 취소했습니다", "Save failed · changes cancelled", "保存失敗・変更を取り消しました", "Error al guardar · cambios cancelados", "Échec d’enregistrement · changements annulés", "Falha ao salvar · alterações canceladas") }
    var saveRecovered: String { t("정상 백업에서 복구했습니다. 최근 진행을 확인하세요.", "Recovered a valid backup. Check recent progress.", "バックアップから復元しました。進行を確認してください。", "Copia recuperada. Revisa el progreso.", "Sauvegarde restaurée. Vérifiez la progression.", "Backup restaurado. Confira o progresso.") }
    var backups: String { t("세이브 백업 폴더", "Save backups", "保存バックアップ", "Copias de seguridad", "Sauvegardes", "Backups") }
    var openingSettings: String { t("개봉과 기록", "Opening and history", "開封と履歴", "Apertura e historial", "Ouverture et historique", "Abertura e histórico") }
    func openingMode(_ mode: OpeningMode) -> String {
        mode == .game ? t("게임 보정", "Game bonuses", "ゲーム補正", "Bonos", "Bonus", "Bônus")
            : t("실물 구성", "Physical model", "実物モデル", "Modelo físico", "Modèle physique", "Modelo físico")
    }
    var realisticNote: String { t("실물 구성: 천장·히트 확률 혜택 없음. 미공개 확률은 추정치이며 할인·판매 혜택은 유지됩니다.", "Physical model: no pity or hit-odds perks. Unpublished rates remain estimates; economic perks remain active.", "実物モデル：天井・排出率補正なし。非公開確率は推定。価格特典は維持。", "Sin garantía ni bono de rareza. Tasas no publicadas estimadas; descuentos activos.", "Sans garantie ni bonus de rareté. Taux inconnus estimés ; remises actives.", "Sem garantia nem bônus de raridade. Taxas estimadas; descontos ativos.") }
    var exportHistory: String { t("개봉 이력 내보내기", "Export opening history", "開封履歴を書き出す", "Exportar historial", "Exporter l’historique", "Exportar histórico") }
    var historyNote: String { t("최근 1,000팩 · 판형, 시드, 확률표 버전, 가격 기준일 포함", "Last 1,000 packs · printings, seed, rules and price dates", "直近1,000パック・印刷仕様、シード、規則、価格日付", "Últimos 1.000 sobres · semilla y precios", "1 000 derniers boosters · graine et prix", "Últimos 1.000 pacotes · semente e preços") }
    var customBuild: String { t("로컬 개선본 · 원본 자동 업데이트 차단", "Local custom build · upstream updates blocked", "ローカル版・上流更新無効", "Versión local · actualización original bloqueada", "Version locale · mises à jour amont bloquées", "Versão local · atualizações originais bloqueadas") }
    var customUpdateNote: String { t("앱 업데이트는 이 소스의 scripts/build-app.sh로만 설치합니다. 외부 Homebrew 명령까지 차단하지는 않습니다.", "App updates use this source’s scripts/build-app.sh. External Homebrew commands are not blocked.", "アプリ更新はこのソースのscripts/build-app.sh。外部Homebrew操作は対象外。", "Actualiza con scripts/build-app.sh. Homebrew externo no se bloquea.", "Mise à jour via scripts/build-app.sh. Homebrew externe n’est pas bloqué.", "Atualize via scripts/build-app.sh. Homebrew externo não é bloqueado.") }
    var priceData: String { t("가격 스냅샷", "Price snapshot", "価格スナップショット", "Precios", "Prix", "Preços") }
    var importPrices: String { t("가격 스냅샷 가져오기", "Import price snapshot", "価格データを読み込む", "Importar precios", "Importer les prix", "Importar preços") }
    var resetPrices: String { t("번들 가격으로 복원", "Use bundled prices", "同梱価格に戻す", "Restaurar precios", "Restaurer les prix", "Restaurar preços") }
    var pricesApplied: String { t("가격을 적용했습니다", "Prices applied", "価格を適用しました", "Precios aplicados", "Prix appliqués", "Preços aplicados") }
    var confirmPriceImport: String { t("이 가격 스냅샷을 적용할까요? 팩 구매가와 카드 판매가가 바뀝니다.", "Apply this snapshot? Pack costs and card sale values will change.", "適用するとパック購入価格とカード売却価格が変わります。", "¿Aplicar? Cambiarán los precios de compra y venta.", "Appliquer ? Les prix d’achat et de vente changeront.", "Aplicar? Os preços de compra e venda mudarão.") }
    var exactPrintingPrice: String { t("판형별 시세", "Exact printing price", "仕様別価格", "Precio por variante", "Prix par variante", "Preço por variante") }
    var completedSalesReference: String {
        t("실거래 기반 참고가", "Completed-sales estimate", "成約価格に基づく参考値", "Estimación según ventas", "Estimation selon ventes", "Estimativa por vendas")
    }
    var mixedPriceSource: String {
        t("카드·판형별 가격 합계입니다. 일부는 실거래 기반 참고가이며, 출처와 기준일은 카드 상세에서 확인할 수 있습니다.",
          "Sum of card and printing quotes, including some completed-sales estimates. See each card for its source and date.",
          "カード・仕様別価格の合計です。一部は成約価格参考値です。出典と日付は各カードで確認できます。",
          "Suma de precios por carta y variante, con algunas estimaciones. Fuente y fecha en cada carta.",
          "Somme des prix par carte et variante, dont certaines estimations. Source et date sur chaque carte.",
          "Soma dos preços por carta e variante, incluindo estimativas. Fonte e data em cada carta.")
    }
    var latestQuoteDate: String { t("최신 기준일", "Latest quote date", "最新価格日", "Última fecha", "Date la plus récente", "Data mais recente") }
    func cardPriceSource(_ prices: CardPrices, cardID: String, finish: CardFinish?) -> String {
        let date = prices.sourceDate(cardID: cardID, finish: finish)
        let description = prices.isReference(cardID: cardID, finish: finish)
            ? "\(completedSalesReference) · \(date)\n" + t("영문·미감정 카드 기준. 실제 판매 보장 가격이 아닙니다.",
                "English, ungraded cards. Not a guaranteed sale price.", "英語版・未鑑定。売却保証額ではありません。",
                "Cartas inglesas sin graduar. Venta no garantizada.", "Cartes anglaises non gradées. Vente non garantie.",
                "Cartas inglesas sem graduação. Venda não garantida.")
            : marketPriceSource(date)
        guard let url = prices.sourceURL(cardID: cardID, finish: finish), !url.isEmpty else { return description }
        return "\(description)\n\(url)"
    }
    var fallbackPrintingPrice: String { t("판형 시세 없음 · 카드 대표값", "No printing quote · representative price", "仕様別価格なし・代表価格", "Sin precio de variante · representativo", "Sans prix de variante · représentatif", "Sem preço de variante · representativo") }
    func quoteBasis(_ basis: PackPriceQuote.Basis) -> String {
        switch basis {
        case .market: t("밀봉 팩 시장가 기준", "Sealed market basis", "未開封相場基準", "Mercado sellado", "Marché scellé", "Mercado lacrado")
        case .economyFloor: t("게임 경제 하한 적용", "Game economy floor applied", "ゲーム価格下限適用", "Mínimo del juego", "Plancher du jeu", "Mínimo do jogo")
        case .expectedValue: t("시장가 없음 · 카드 기대값 기준", "No market quote · expected card value", "相場なし・カード期待値", "Sin cotización · valor esperado", "Sans cotation · valeur attendue", "Sem cotação · valor esperado")
        case .fallback: t("가격 데이터 없음 · 기본 게임 가격", "No price data · fallback game price", "価格なし・ゲーム既定値", "Sin datos · precio básico", "Sans données · prix par défaut", "Sem dados · preço padrão")
        }
    }
}
