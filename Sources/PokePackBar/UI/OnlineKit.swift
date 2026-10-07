import AppKit
import SwiftUI

/// 온라인 창이 함께 쓰는 말투와 조각.
///
/// 서버 값(영문 상태, 판형 코드, 토큰 정수)을 화면에 그대로 내보내지 않는다. 사용자가 보는 돈은
/// 앱 머리글과 같은 원화이고, 서버로 보낼 때만 토큰으로 바꾼다.
@MainActor
enum OnlineText {
    static let l = L(.ko)

    static func cardName(_ cardID: String) -> String {
        CardIndex.shared?.card(cardID)?.displayName(.ko) ?? cardID
    }

    static func finish(_ raw: String) -> String {
        CardFinish(rawValue: raw).map(l.cardFinishName) ?? raw
    }

    static func printing(_ key: String) -> (name: String, finish: String) {
        let printing = CardPrintingKey(storageKey: key)
        return (cardName(printing.cardID), l.cardFinishName(printing.finish))
    }

    /// 토큰을 원화로. 시장 가격은 천 원 단위로 뭉개면 안 되므로 끊지 않은 표기를 쓴다.
    static func won(tokens: Int) -> String {
        WonFormatter.exact(MarketEconomy.won(tokens: tokens), language: .ko)
    }

    /// 원화 입력을 서버가 받는 토큰으로. 100원 칸 단위로 맞춘다.
    static let maximumListingTokens = 1_000_000_000_000
    static var maximumListingWon: Int {
        maximumListingTokens / MarketEconomy.stepTokens() * MarketEconomy.wonStep
    }
    static func tokens(won: Int) -> Int? {
        let step = MarketEconomy.stepTokens()
        let units = won / MarketEconomy.wonStep
        guard won >= MarketEconomy.wonStep, units <= maximumListingTokens / step else { return nil }
        return units * step
    }

    /// 참고 시세를 원화 100원 칸으로.
    static func referenceWon(_ key: String) -> Int? {
        let printing = CardPrintingKey(storageKey: key)
        guard let prices = CardPrices.shared, let usd = prices.price(printing) else { return nil }
        return MarketEconomy.won(tokens: MarketEconomy.tokens(usd: usd, prices: prices), prices: prices)
    }

    static func wonText(_ won: Int) -> String { WonFormatter.exact(won, language: .ko) }

    static func listingStatus(_ raw: String) -> (text: String, color: Color) {
        switch raw {
        case "active": return ("판매 중", .green)
        case "sold": return ("다 팔림", .blue)
        case "expired": return ("기간 끝남", .secondary)
        case "cancelled": return ("내림", .secondary)
        default: return (raw, .secondary)
        }
    }

    static func tradeStatus(_ raw: String) -> (text: String, color: Color) {
        switch raw {
        case "pending": return ("답 기다리는 중", .orange)
        case "accepted": return ("교환 완료", .green)
        case "rejected": return ("거절됨", .secondary)
        case "cancelled": return ("취소됨", .secondary)
        case "expired": return ("기간 끝남", .secondary)
        default: return (raw, .secondary)
        }
    }

    static func notification(_ kind: String) -> (text: String, icon: String) {
        switch kind {
        case "trade_request": return ("새 교환 제안이 왔어요", "arrow.left.arrow.right")
        case "trade_accepted": return ("교환이 성사됐어요", "checkmark.circle")
        case "trade_rejected": return ("교환 제안이 거절됐어요", "xmark.circle")
        case "trade_cancelled": return ("교환 제안이 취소됐어요", "xmark.circle")
        case "trade_expired": return ("교환 제안 기간이 끝났어요", "clock")
        case "listing_sold": return ("올린 카드가 팔렸어요", "wonsign.circle")
        case "listing_bought": return ("마켓에서 카드를 샀어요", "bag")
        case "listing_expired": return ("판매 기간이 끝나 카드가 돌아왔어요", "clock")
        case "wishlist_listing": return ("위시리스트 카드가 마켓에 올라왔어요", "star")
        case "friend_request": return ("친구 신청이 왔어요", "person.badge.plus")
        case "friend_accept", "friend_accepted": return ("친구 신청이 수락됐어요", "person.2")
        case "friend_reject", "friend_rejected": return ("친구 신청이 거절됐어요", "person.badge.minus")
        case "friend_expired": return ("친구 신청 기간이 끝났어요", "clock")
        default: return (kind, "bell")
        }
    }

    /// "6일 남음" 처럼 남은 시간만 말한다. 날짜와 시각을 통째로 보여 주면 계산을 떠넘긴다.
    static func remaining(until timestamp: Int) -> String {
        let seconds = Double(timestamp) - Date().timeIntervalSince1970
        guard seconds > 0 else { return "기간 끝남" }
        let hours = Int(seconds / 3600)
        if hours >= 48 { return "\(hours / 24)일 남음" }
        if hours >= 1 { return "\(hours)시간 남음" }
        return "곧 끝나요"
    }
}

/// 내가 팔거나 교환에 내놓을 수 있는 인쇄본. 한 장은 늘 남기고, 다른 거래에 묶인 장수는 뺀다.
struct OnlineStock: Identifiable, Sendable {
    let key: String
    let cardID: String
    let finish: CardFinish
    let available: Int
    let referenceWon: Int?
    var id: String { key }

    @MainActor
    static func sellable(wallet: WalletStore) -> [OnlineStock] {
        guard let index = CardIndex.shared else { return [] }
        let reserved = wallet.remote?.reservedPrintings ?? [:]
        return wallet.state.printingCards.compactMap { key, count -> OnlineStock? in
            let printing = CardPrintingKey(storageKey: key)
            guard index.card(printing.cardID) != nil else { return nil }
            let available = count - (reserved[key] ?? 0) - 1
            guard available > 0 else { return nil }
            return OnlineStock(key: key, cardID: printing.cardID, finish: printing.finish,
                               available: available, referenceWon: OnlineText.referenceWon(key))
        }
        .sorted { ($0.referenceWon ?? 0, $0.key) > ($1.referenceWon ?? 0, $1.key) }
    }
}

/// 카드 그림이 먼저 보이는 칸. 이름과 판형 아래에 각 화면이 필요한 한두 줄을 붙인다.
struct OnlineCardTile<Footer: View>: View {
    let cardID: String
    let finish: String
    var width: CGFloat = 112
    var badge: (text: String, color: Color)? = nil
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                CardImageView(cardID: cardID, width: width)
                if let badge {
                    OnlineBadge(text: badge.text, color: badge.color).padding(4)
                }
            }
            Text(OnlineText.cardName(cardID))
                .font(Typography.labelSemibold).lineLimit(1)
            Text(OnlineText.finish(finish))
                .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
            footer
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct OnlineBadge: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(Typography.captionMedium)
            .foregroundStyle(color == .secondary ? Color.secondary : color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background((color == .secondary ? Color.secondary : color).opacity(0.14), in: Capsule())
    }
}

/// 비어 있을 때 무엇을 하면 채워지는지까지 말한다.
struct OnlineEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.secondary)
            Text(title).font(Typography.bodySemibold)
            if let message {
                Text(message).font(Typography.label).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// 한 덩어리의 내용. 모든 것을 상자에 넣지 않고, 제목과 여백으로 나눈다.
struct OnlineSection<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.title)
                    if let subtitle {
                        Text(subtitle).font(Typography.label).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                accessory
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension OnlineSection where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = EmptyView()
        self.content = content()
    }
}

/// 수량 고르기. 숫자 칸 대신 −/+ 로만 바꾼다 — 고를 수 없는 수는 아예 못 만든다.
struct OnlineQuantity: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 10) {
            Button { value = max(range.lowerBound, value - 1) } label: { Image(systemName: "minus") }
                .disabled(value <= range.lowerBound)
            Text("\(value)장").font(Typography.bodySemibold).monospacedDigit().frame(minWidth: 52)
            Button { value = min(range.upperBound, value + 1) } label: { Image(systemName: "plus") }
                .disabled(value >= range.upperBound)
            if range.upperBound > 1 {
                Button("최대") { value = range.upperBound }
                    .buttonStyle(.borderless).font(Typography.label)
                    .disabled(value == range.upperBound)
            }
        }
        .onAppear { value = min(max(value, range.lowerBound), range.upperBound) }
    }
}

/// 시트 공통 틀: 제목, 내용, 아래쪽 취소와 실행 버튼.
struct OnlineSheet<Content: View>: View {
    let title: String
    let actionTitle: String
    var actionDisabled = false
    var note: String? = nil
    let action: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(Typography.heading)
            content
            if let note {
                Text(note).font(Typography.label).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle) { dismiss(); action() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(actionDisabled)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

/// 이전/다음. 넘길 곳이 없으면 아예 보이지 않는다.
struct OnlinePagination: View {
    @Bindable var model: OnlineHubModel
    let key: String
    var step = 50

    var body: some View {
        let hasNext = model.documents[key]?["next_offset"] as? Int != nil
        if model.offset > 0 || hasNext {
            HStack {
                Button("이전") { model.offset = max(0, model.offset - step); Task { await model.refresh(full: false) } }
                    .disabled(model.offset == 0 || model.loading)
                Button("다음") { model.offset += step; Task { await model.refresh(full: false) } }
                    .disabled(!hasNext || model.loading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 카드 그림 줄. 교환처럼 여러 장을 한눈에 보여 줄 때 쓴다.
struct OnlineCardStrip: View {
    let lines: [String: Int]
    var width: CGFloat = 64
    var onRemove: ((String) -> Void)? = nil
    var onOpen: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(lines.keys.sorted(), id: \.self) { key in
                    let printing = CardPrintingKey(storageKey: key)
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            CardImageView(cardID: printing.cardID, width: width)
                                .onTapGesture { onOpen?(key) }
                            if let onRemove {
                                Button { onRemove(key) } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .buttonStyle(.plain).offset(x: 5, y: -5)
                                .help("빼기")
                            }
                        }
                        Text("×\(lines[key] ?? 0)").font(Typography.captionMedium).monospacedDigit()
                    }
                    .help("\(OnlineText.printing(key).name) \(OnlineText.printing(key).finish)")
                }
            }
            .padding(.top, 6)
        }
    }
}

/// 전체 카드에서 원하는 카드를 찾아 고르는 시트. 위시리스트와 교환의 「받고 싶은 카드」에 쓴다.
/// 판형은 그 카드에 실제로 있는 것만 고를 수 있다.
struct OnlineCatalogueSearch: View {
    let title: String
    let actionTitle: String
    var allowsAnyFinish = false
    var maxQuantity = 1000
    let onPick: (_ cardID: String, _ finish: CardFinish?, _ quantity: Int) -> Void

    @State private var query = ""
    @State private var picked: CardEntry?
    @State private var finish: CardFinish?
    @State private var quantity = 1
    @Environment(\.dismiss) private var dismiss

    private var results: [CardEntry] {
        let needle = DexCardSearch.normalized(query)
        guard !needle.isEmpty, let index = CardIndex.shared else { return [] }
        return Array(index.cards.lazy.filter { entry in
            [entry.name, entry.nameKo].compactMap { $0 }
                .contains { DexCardSearch.normalized($0).contains(needle) }
        }.prefix(60))
    }

    private func finishes(_ card: CardEntry) -> [CardFinish] {
        guard let index = CardIndex.shared else { return [] }
        var seen: [CardFinish] = []
        for option in FoilAuditPrintings.finishes(for: card, index: index) {
            let resolved = option ?? CardFinishResolver.resolve(
                cardID: card.id, setID: card.setID, originalRarity: card.rarity,
                tier: card.tier, visualKind: card.visualKind, explicitFinish: nil).finish
            if !seen.contains(resolved) { seen.append(resolved) }
        }
        return seen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Typography.heading)
            if let picked {
                HStack(alignment: .top, spacing: 16) {
                    CardImageView(cardID: picked.id, hires: true, width: 150)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(picked.displayName(.ko)).font(Typography.title)
                        Text(CardIndex.shared?.set(picked.setID)?.name ?? picked.setID)
                            .font(Typography.label).foregroundStyle(.secondary)
                        Picker("판형", selection: $finish) {
                            if allowsAnyFinish { Text("어떤 판형이든").tag(CardFinish?.none) }
                            ForEach(finishes(picked), id: \.self) { option in
                                Text(OnlineText.l.cardFinishName(option)).tag(Optional(option))
                            }
                        }
                        .fixedSize()
                        OnlineQuantity(value: $quantity, range: 1...maxQuantity)
                        Button("다른 카드 고르기") { self.picked = nil }.buttonStyle(.borderless)
                    }
                }
            } else {
                TextField("카드 이름으로 찾기 (한국어, 영어)", text: $query)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    if query.isEmpty {
                        OnlineEmptyState(icon: "magnifyingglass", title: "찾을 카드 이름을 입력하세요")
                    } else if results.isEmpty {
                        OnlineEmptyState(icon: "questionmark.square", title: "맞는 카드가 없어요")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                            ForEach(results) { card in
                                Button {
                                    picked = card
                                    finish = allowsAnyFinish ? nil : finishes(card).first
                                    quantity = 1
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        CardImageView(cardID: card.id, width: 92)
                                        Text(card.displayName(.ko)).font(Typography.caption).lineLimit(1)
                                        Text(CardIndex.shared?.set(card.setID)?.name ?? card.setID)
                                            .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    .frame(width: 92)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 360)
            }
            HStack {
                Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle) {
                    if let picked { onPick(picked.id, finish, quantity) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(picked == nil || (!allowsAnyFinish && finish == nil))
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

/// 내 카드 중 거래할 수 있는 것만 보여 주고 골라 담는 시트.
struct OnlineStockPicker: View {
    let wallet: WalletStore
    let title: String
    let actionTitle: String
    /// 이미 담은 장수. 남은 수량을 넘겨 담지 않게 한다.
    var alreadyPicked: [String: Int] = [:]
    let onPick: (_ key: String, _ quantity: Int) -> Void

    @State private var query = ""
    @State private var picked: OnlineStock?
    @State private var quantity = 1
    @Environment(\.dismiss) private var dismiss

    private var stock: [OnlineStock] {
        let all = OnlineStock.sellable(wallet: wallet)
        let needle = DexCardSearch.normalized(query)
        guard !needle.isEmpty else { return all }
        return all.filter { DexCardSearch.normalized(OnlineText.cardName($0.cardID)).contains(needle)
            || DexCardSearch.normalized(CardIndex.shared?.card($0.cardID)?.name ?? "").contains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Typography.heading)
            if let picked {
                let remaining = max(1, picked.available)
                HStack(alignment: .top, spacing: 16) {
                    CardImageView(cardID: picked.cardID, hires: true, width: 150)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(OnlineText.cardName(picked.cardID)).font(Typography.title)
                        Text(OnlineText.l.cardFinishName(picked.finish))
                            .font(Typography.label).foregroundStyle(.secondary)
                        Text("내놓을 수 있는 카드 \(picked.available)장")
                            .font(Typography.label)
                        OnlineQuantity(value: $quantity, range: 1...min(1000, remaining))
                        Button("다른 카드 고르기") { self.picked = nil }.buttonStyle(.borderless)
                    }
                }
            } else {
                TextField("내 카드에서 찾기", text: $query).textFieldStyle(.roundedBorder)
                ScrollView {
                    if stock.isEmpty {
                        OnlineEmptyState(icon: "square.stack",
                                         title: query.isEmpty ? "내놓을 수 있는 카드가 없어요" : "맞는 카드가 없어요",
                                         message: query.isEmpty ? "같은 카드를 2장 이상 가지고 있으면 여기에 나타나요. 한 장은 늘 남겨 둬요." : nil)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                            ForEach(stock) { item in
                                Button {
                                    picked = OnlineStock(key: item.key, cardID: item.cardID, finish: item.finish,
                                                         available: item.available - (alreadyPicked[item.key] ?? 0),
                                                         referenceWon: item.referenceWon)
                                    quantity = 1
                                } label: {
                                    OnlineCardTile(cardID: item.cardID, finish: item.finish.rawValue, width: 92) {
                                        Text("\(item.available)장 가능").font(Typography.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(item.available - (alreadyPicked[item.key] ?? 0) <= 0)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 360)
            }
            HStack {
                Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(actionTitle) {
                    if let picked { onPick(picked.key, quantity) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(picked == nil || (picked?.available ?? 0) < 1)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

// MARK: 실패 안내

/// 실패를 사용자가 구분할 수 있는 종류로. 연결 실패와 서버 오류를 같은 말로 뭉뚱그리면
/// 인터넷을 고칠지 기다릴지 알 수 없다.
struct OnlineProblem {
    enum Kind { case unreachable, server, rejected, other }
    let kind: Kind
    let requestID: String?

    init(_ error: (any Error)?) {
        let traced = error as? any ServerTraceable
        requestID = traced?.requestID
        switch traced?.status {
        case .none where error is ServerUnreachable: kind = .unreachable
        case .some(let status) where status >= 500: kind = .server
        case .some(let status) where status >= 400: kind = .rejected
        default: kind = .other
        }
    }

    var title: String {
        switch kind {
        case .unreachable: "서버에 연결하지 못했어요"
        case .server: "서버에서 오류가 났어요"
        case .rejected: "요청이 처리되지 않았어요"
        case .other: "온라인 기능을 잠시 쓸 수 없어요"
        }
    }

    var icon: String {
        switch kind {
        case .unreachable: "wifi.exclamationmark"
        case .server: "exclamationmark.icloud"
        case .rejected, .other: "exclamationmark.circle"
        }
    }

    var hint: String {
        switch kind {
        case .unreachable: "마지막으로 불러온 내용을 보여 주는 중이에요. 연결되면 다시 거래할 수 있어요."
        case .server: "내 카드와 금액은 바뀌지 않았어요. 계속되면 아래 요청 번호를 알려 주세요."
        case .rejected, .other: "마지막으로 불러온 내용을 보여 주는 중이에요."
        }
    }
}

/// 온라인 창 위쪽의 실패 안내. 요청 번호는 서버 로그의 request_id 와 같아서, 복사해 두면
/// 서버에서 그 요청의 오류 기록을 바로 찾을 수 있다.
struct OnlineFailureBanner: View {
    let problem: OnlineProblem
    let message: String
    let loading: Bool
    let retry: () -> Void
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: problem.icon).foregroundStyle(.orange).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(problem.title).font(Typography.bodySemibold)
                Text(problem.hint).font(Typography.label).foregroundStyle(.secondary)
                Text(message).font(Typography.label).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                HStack(spacing: 10) {
                    if let id = problem.requestID {
                        Text("요청 번호 \(id.prefix(8))").monospaced().textSelection(.enabled)
                        Button(copied ? "복사했어요" : "복사") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(id, forType: .string)
                            copied = true
                        }
                        .buttonStyle(.link)
                    }
                    Button("로그 보기") { NSWorkspace.shared.activateFileViewerSelecting([AppLog.logFileURL]) }
                        .buttonStyle(.link)
                }
                .font(Typography.label).foregroundStyle(.secondary)
            }
            Spacer()
            Button("다시 시도", action: retry).disabled(loading)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: problem.requestID) { copied = false }
    }
}
