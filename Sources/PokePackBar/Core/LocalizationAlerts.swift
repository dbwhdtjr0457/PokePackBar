import Foundation

/// 온라인 알림의 문구. 알림 탭과 macOS 알림이 같은 문장을 쓴다.
///
/// 「새 교환 제안이 왔어요」만으로는 누가 무엇을 했는지 알 수 없어 탭을 열어 봐야 했다. 서버가
/// 상대 이름과 카드를 함께 보내면 그것을 넣어 말하고, 보내지 않는 예전 서버에서는 짧은 문장으로 남는다.
///
/// 교환의 수락, 거절, 취소, 만료 알림은 양쪽 모두에게 가므로 「누가 했다」가 아니라 「누구와의
/// 교환이 어떻게 됐다」로 적는다. 내가 거절한 기록이 상대가 거절한 것처럼 읽히면 안 된다.
extension L {
    func noteTradeRequestFrom(_ name: String) -> String {
        t("\(name) 님이 교환을 제안했어요", "\(name) sent you a trade offer", "\(name)さんから交換の提案が届きました",
          "\(name) te envió una oferta de intercambio", "\(name) vous a envoyé une offre d’échange",
          "\(name) enviou uma proposta de troca")
    }
    func noteTradeCounteredBy(_ name: String) -> String {
        t("\(name) 님이 역제안을 보냈어요", "\(name) sent a counter-offer", "\(name)さんから逆提案が届きました",
          "\(name) envió una contraoferta", "\(name) a envoyé une contre-offre", "\(name) enviou uma contraproposta")
    }
    func noteTradeAcceptedWith(_ name: String) -> String {
        t("\(name) 님과 교환이 성사됐어요", "Trade with \(name) completed", "\(name)さんとの交換が成立しました",
          "Intercambio con \(name) completado", "Échange avec \(name) conclu", "Troca com \(name) concluída")
    }
    func noteTradeRejectedWith(_ name: String) -> String {
        t("\(name) 님과의 교환 제안이 거절됐어요", "Trade offer with \(name) was declined",
          "\(name)さんとの交換の提案が断られました", "La oferta con \(name) fue rechazada",
          "L’offre avec \(name) a été refusée", "A proposta com \(name) foi recusada")
    }
    func noteTradeCancelledWith(_ name: String) -> String {
        t("\(name) 님과의 교환 제안이 취소됐어요", "Trade offer with \(name) was cancelled",
          "\(name)さんとの交換の提案が取り消されました", "La oferta con \(name) fue cancelada",
          "L’offre avec \(name) a été annulée", "A proposta com \(name) foi cancelada")
    }
    func noteTradeExpiredWith(_ name: String) -> String {
        t("\(name) 님과의 교환 제안 기간이 끝났어요", "Trade offer with \(name) expired",
          "\(name)さんとの交換の提案が期限切れになりました", "La oferta con \(name) caducó",
          "L’offre avec \(name) a expiré", "A proposta com \(name) expirou")
    }
    func noteFriendRequestFrom(_ name: String) -> String {
        t("\(name) 님이 친구 신청을 보냈어요", "\(name) sent you a friend request", "\(name)さんからフレンド申請が届きました",
          "\(name) te envió una solicitud de amistad", "\(name) vous a envoyé une demande d’ami",
          "\(name) enviou um pedido de amizade")
    }
    func noteFriendAcceptedBy(_ name: String) -> String {
        t("\(name) 님이 친구 신청을 수락했어요", "\(name) accepted your friend request",
          "\(name)さんがフレンド申請を承認しました", "\(name) aceptó tu solicitud de amistad",
          "\(name) a accepté votre demande d’ami", "\(name) aceitou seu pedido de amizade")
    }
    func noteFriendRejectedBy(_ name: String) -> String {
        t("\(name) 님이 친구 신청을 거절했어요", "\(name) declined your friend request",
          "\(name)さんがフレンド申請を断りました", "\(name) rechazó tu solicitud de amistad",
          "\(name) a refusé votre demande d’ami", "\(name) recusou seu pedido de amizade")
    }
    func noteFriendExpiredWith(_ name: String) -> String {
        t("\(name) 님과의 친구 신청 기간이 끝났어요", "Friend request with \(name) expired",
          "\(name)さんとのフレンド申請が期限切れになりました", "La solicitud con \(name) caducó",
          "La demande avec \(name) a expiré", "O pedido com \(name) expirou")
    }
    var noteFriendRemoved: String {
        t("친구 관계가 끊겼어요", "A friend removed you", "フレンドが解除されました", "Un amigo te eliminó",
          "Un ami vous a retiré", "Um amigo removeu você")
    }
    func noteFriendRemovedBy(_ name: String) -> String {
        t("\(name) 님과 친구가 끊겼어요", "\(name) is no longer your friend", "\(name)さんとのフレンドが解除されました",
          "\(name) ya no es tu amigo", "\(name) n’est plus votre ami", "\(name) não é mais seu amigo")
    }
    func noteListingSoldCard(_ card: String, price: String) -> String {
        t("\(card) 카드가 팔렸어요 (장당 \(price))", "\(card) sold (\(price) each)", "\(card)が売れました（1枚 \(price)）",
          "Se vendió \(card) (\(price) cada una)", "\(card) s’est vendue (\(price) l’unité)",
          "\(card) foi vendida (\(price) cada)")
    }
    func noteListingBoughtCard(_ card: String) -> String {
        t("\(card) 카드를 샀어요", "You bought \(card)", "\(card)を買いました", "Compraste \(card)",
          "Vous avez acheté \(card)", "Você comprou \(card)")
    }
    func noteListingExpiredCard(_ card: String) -> String {
        t("\(card) 판매 기간이 끝나 카드가 돌아왔어요", "Listing for \(card) expired, the card is back",
          "\(card)の出品期限が切れてカードが戻りました", "La venta de \(card) caducó y la carta volvió",
          "La vente de \(card) a expiré, la carte est revenue", "A venda de \(card) expirou e a carta voltou")
    }
    func noteWishlistListingCard(_ card: String, price: String) -> String {
        t("위시리스트의 \(card) 카드가 마켓에 올라왔어요 (\(price))", "\(card) from your wishlist is on the market (\(price))",
          "ウィッシュリストの\(card)が出品されました（\(price)）", "\(card) de tu lista de deseos está en venta (\(price))",
          "\(card) de votre liste d’envies est en vente (\(price))", "\(card) da sua lista de desejos está à venda (\(price))")
    }

    // MARK: 알림 탭

    /// 이번에 처음 본 알림 수. 보고 있으면 저절로 읽음이 되므로 「안 읽은」 대신 「새」 라고 한다.
    func newAlerts(_ n: Int) -> String {
        t("새 알림 \(n)개", "\(n) new", "新着 \(n)件", "\(n) nuevas", "\(n) nouvelles", "\(n) novas")
    }
    var allAlertsRead: String {
        t("모두 읽었어요", "All caught up", "すべて既読です", "Todo leído", "Tout est lu", "Tudo lido")
    }

    var justNow: String { t("방금", "Just now", "たった今", "Ahora", "À l’instant", "Agora") }
    func minutesAgo(_ n: Int) -> String {
        t("\(n)분 전", "\(n)m ago", "\(n)分前", "Hace \(n) min", "Il y a \(n) min", "Há \(n) min")
    }
    func hoursAgo(_ n: Int) -> String {
        t("\(n)시간 전", "\(n)h ago", "\(n)時間前", "Hace \(n) h", "Il y a \(n) h", "Há \(n) h")
    }
    func daysAgo(_ n: Int) -> String {
        t("\(n)일 전", "\(n)d ago", "\(n)日前", "Hace \(n) d", "Il y a \(n) j", "Há \(n) d")
    }

    // MARK: macOS 알림

    var onlineNotificationsLabel: String {
        t("온라인 알림", "Online alerts", "オンライン通知", "Avisos en línea", "Alertes en ligne", "Avisos online")
    }
    var onlineNotificationsHint: String {
        t("교환 제안, 마켓 판매, 친구 신청을 macOS 알림으로 받아요",
          "Trade offers, market sales and friend requests as macOS notifications",
          "交換の提案、マーケットの販売、フレンド申請をmacOSの通知で受け取ります",
          "Ofertas de intercambio, ventas y solicitudes de amistad como notificaciones de macOS",
          "Offres d’échange, ventes et demandes d’ami en notifications macOS",
          "Propostas de troca, vendas e pedidos de amizade como notificações do macOS")
    }
    func newAlertsCount(_ n: Int) -> String {
        t("새 알림 \(n)개", "\(n) new alerts", "新しい通知 \(n)件", "\(n) avisos nuevos", "\(n) nouvelles alertes",
          "\(n) alertas novos")
    }
    func andMoreAlerts(_ first: String, _ rest: Int) -> String {
        t("\(first) 외 \(rest)개", "\(first), and \(rest) more", "\(first) ほか\(rest)件", "\(first) y \(rest) más",
          "\(first) et \(rest) de plus", "\(first) e mais \(rest)")
    }
}
