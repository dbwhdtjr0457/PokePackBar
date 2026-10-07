import SwiftUI

// MARK: - 마켓

/// 마켓 — 사기, 팔기, 내 판매.
///
/// 예전 화면은 등록 폼, 검색, 장부, 글 목록을 한 화면에 쌓고, 전체 카드 목록에서 고른 뒤에야
/// 「거래 가능 0장」을 알려 줬다. 지금은 할 일마다 화면을 나누고, 팔 수 있는 카드만 보여 준다.
/// 서버 경로와 보내는 값은 그대로다.
@MainActor
struct OnlineMarketView: View {
    @Bindable var model: OnlineHubModel
    @State private var mode: Mode = .buy
    @State private var buying: [String: Any]?
    @State private var selling: OnlineStock?
    @State private var sellQuery = ""
    @State private var preview: PrintingSelection?

    enum Mode: String, CaseIterable, Identifiable {
        case buy, sell, mine
        var id: String { rawValue }
        @MainActor var title: String {
            switch self {
            case .buy: OnlineText.l.marketBuy
            case .sell: OnlineText.l.marketSell
            case .mine: OnlineText.l.mySales
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .onChange(of: mode) {
                model.offset = 0
                model.ownListings = mode == .mine
                if mode != .sell { Task { await model.refresh(full: false) } }
            }

            switch mode {
            case .buy: buyView
            case .sell: sellView
            case .mine: mineView
            }
        }
        .onAppear { model.ownListings = mode == .mine }
        .sheet(item: Binding(get: { buying.map(ListingBox.init) }, set: { buying = $0?.item })) { box in
            BuySheet(model: model, item: box.item)
        }
        .sheet(item: $selling) { stock in SellSheet(model: model, stock: stock) }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    // MARK: 사기

    private var buyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField(OnlineText.l.searchByCardName, text: $model.search)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    .onSubmit { reload() }
                Picker(OnlineText.l.setLabel, selection: $model.marketSet) {
                    Text(OnlineText.l.allSetsOption).tag("")
                    ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
                }
                .fixedSize()
                Picker(OnlineText.l.tierLabel, selection: $model.marketTier) {
                    Text(OnlineText.l.allTiers).tag("")
                    ForEach(CardIndex.shared?.presentTiers ?? [], id: \.self) { tier in
                        Text("\(tier.rawValue) \(OnlineText.l.tierName(tier))").tag(tier.rawValue)
                    }
                }
                .fixedSize()
                Picker(OnlineText.l.sortLabel, selection: $model.marketSort) {
                    Text(OnlineText.l.sortNewest).tag("newest")
                    Text(OnlineText.l.sortPrice).tag("price")
                }
                .fixedSize()
            }
            .labelsHidden()
            .onChange(of: model.marketSet) { reload() }
            .onChange(of: model.marketTier) { reload() }
            .onChange(of: model.marketSort) { reload() }
            .task(id: model.search) {
                // 치는 대로 찾는다. 글자마다 서버에 묻지 않도록 잠깐 멈춘 뒤에만.
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                model.offset = 0
                await model.refresh(full: false)
            }

            let listings = model.items("listings")
            ScrollView {
                if listings.isEmpty {
                    OnlineEmptyState(icon: "bag",
                                     title: hasFilter ? OnlineText.l.noListingsMatch : OnlineText.l.noListingsYet,
                                     message: hasFilter ? OnlineText.l.narrowFilters : OnlineText.l.listingsAppearHere)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16)], alignment: .leading, spacing: 18) {
                        ForEach(listings, id: \.onlineID) { item in
                            let printing = CardPrintingKey(storageKey: item.string("printing"))
                            Button { item.bool("mine") ? (preview = PrintingSelection(id: item.string("printing"))) : (buying = item) } label: {
                                OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue,
                                               badge: item.bool("mine") ? (OnlineText.l.mySales, .accentColor) : nil) {
                                    Text(OnlineText.won(tokens: item.int("unit_tokens")))
                                        .font(Typography.bodySemibold).monospacedDigit()
                                    Text("\(item.string("nickname")), \(OnlineText.l.cardsCount(item.int("quantity")))")
                                        .font(Typography.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    OnlinePagination(model: model, key: "listings")
                }
            }
        }
    }

    private var hasFilter: Bool {
        !model.search.isEmpty || !model.marketSet.isEmpty || !model.marketTier.isEmpty || !model.marketFinish.isEmpty
    }

    // MARK: 팔기

    private var sellView: some View {
        let all = OnlineStock.sellable(wallet: model.wallet)
        let needle = DexCardSearch.normalized(sellQuery)
        let stock = needle.isEmpty ? all : all.filter {
            DexCardSearch.names(cardID: $0.cardID).contains { $0.contains(needle) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(OnlineText.l.searchMyCards, text: $sellQuery)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Spacer()
                Text(OnlineText.l.sellHint)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            ScrollView {
                if stock.isEmpty {
                    OnlineEmptyState(icon: "square.stack",
                                     title: sellQuery.isEmpty ? OnlineText.l.noSellableCards : OnlineText.l.noMatchingCards,
                                     message: sellQuery.isEmpty ? OnlineText.l.spareCardsHint : nil)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16)], alignment: .leading, spacing: 18) {
                        ForEach(stock) { item in
                            Button { selling = item } label: {
                                OnlineCardTile(cardID: item.cardID, finish: item.finish.rawValue) {
                                    Text(OnlineText.l.sellableCount(item.available))
                                        .font(Typography.caption).foregroundStyle(.secondary)
                                    if let won = item.referenceWon {
                                        Text(OnlineText.l.marketQuote(OnlineText.wonText(won)))
                                            .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!model.canWrite)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: 내 판매

    private var mineView: some View {
        let listings = model.items("listings")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                Label(OnlineText.l.earned(OnlineText.won(tokens: model.wallet.state.marketEarnedTokens)), systemImage: "arrow.down.circle")
                Label(OnlineText.l.spent(OnlineText.won(tokens: model.wallet.state.marketSpentTokens)), systemImage: "arrow.up.circle")
            }
            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            ScrollView {
                if listings.isEmpty {
                    OnlineEmptyState(icon: "tag", title: OnlineText.l.noOwnListings,
                                     message: OnlineText.l.listFromSell)
                } else {
                    VStack(spacing: 10) {
                        ForEach(listings, id: \.onlineID) { item in myListing(item) }
                    }
                    OnlinePagination(model: model, key: "listings")
                }
            }
        }
    }

    private func myListing(_ item: [String: Any]) -> some View {
        let printing = CardPrintingKey(storageKey: item.string("printing"))
        let status = OnlineText.listingStatus(item.string("status"))
        return HStack(spacing: 14) {
            CardImageView(cardID: printing.cardID, width: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.bodySemibold)
                    OnlineBadge(text: status.text, color: status.color)
                }
                Text(OnlineText.l.myListingLine(finish: OnlineText.l.cardFinishName(printing.finish), unit: OnlineText.won(tokens: item.int("unit_tokens")), left: item.int("quantity")))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                if item.string("status") == "active" {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.string("status") == "active", item.bool("mine") {
                Button(OnlineText.l.takeDownListing) {
                    Task { await model.mutate("market/listings", ["action": "listing_cancel", "target_id": item.string("id"), "target_version": item.int("version")]) }
                }
                .disabled(!model.canWrite)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func reload() { model.offset = 0; Task { await model.refresh(full: false) } }
}

/// `[String: Any]` 를 시트에 넘기기 위한 상자.
private struct ListingBox: Identifiable {
    let item: [String: Any]
    var id: String { item.onlineID }
}

@MainActor
private struct BuySheet: View {
    @Bindable var model: OnlineHubModel
    let item: [String: Any]
    @State private var quantity = 1

    var body: some View {
        let printing = CardPrintingKey(storageKey: item.string("printing"))
        let unit = item.int("unit_tokens")
        let affordable = unit > 0 ? model.wallet.availableTokens / unit : 0
        let maximum = max(1, min(item.int("quantity"), 1000, affordable))
        let total = unit * quantity
        let canAfford = total <= model.wallet.availableTokens
        OnlineSheet(title: OnlineText.l.buyCardTitle, actionTitle: OnlineText.l.buyFor(OnlineText.won(tokens: total)),
                    actionDisabled: !model.canWrite || !canAfford || affordable < 1,
                    note: OnlineText.l.buyNote,
                    action: {
                        // 보낼 값은 누르는 순간 정한다. Task 본문은 시트가 닫힌 뒤에 돈다.
                        let values: [String: Any] = ["action": "listing_buy", "target_id": item.string("id"), "target_version": item.int("version"), "quantity": quantity, "unit_tokens": unit]
                        Task { await model.mutate("market/listings", values) }
                    }) {
            HStack(alignment: .top, spacing: 18) {
                CardImageView(cardID: printing.cardID, hires: true, width: 150)
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.title)
                    Text(OnlineText.l.soldBy(finish: OnlineText.l.cardFinishName(printing.finish), seller: item.string("nickname")))
                        .font(Typography.label).foregroundStyle(.secondary)
                    Text(OnlineText.l.perCard(OnlineText.won(tokens: unit))).font(Typography.bodySemibold).monospacedDigit()
                    if let reference = OnlineText.referenceWon(item.string("printing")) {
                        Text(OnlineText.l.referencePrice(OnlineText.wonText(reference)))
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                    }
                    OnlineQuantity(value: $quantity, range: 1...maximum)
                    Text(affordable < 1 ? OnlineText.l.notEnoughBalance : OnlineText.l.balanceAfter(OnlineText.won(tokens: max(0, model.wallet.availableTokens - total))))
                        .font(Typography.label).foregroundStyle(affordable < 1 ? Color.orange : Color.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

@MainActor
private struct SellSheet: View {
    @Bindable var model: OnlineHubModel
    let stock: OnlineStock
    @State private var quantity = 1
    @State private var priceWon = 0

    var body: some View {
        let suggested = stock.referenceWon ?? MarketEconomy.wonStep
        let price = max(MarketEconomy.wonStep, (priceWon / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        let listingTokens = OnlineText.tokens(won: price)
        OnlineSheet(title: OnlineText.l.sellCardTitle, actionTitle: OnlineText.l.postListing,
                    actionDisabled: !model.canWrite || priceWon < MarketEconomy.wonStep || listingTokens == nil,
                    note: OnlineText.l.sellNote(quantity: quantity, price: OnlineText.wonText(price)),
                    action: {
                        guard let listingTokens else { return }
                        let values: [String: Any] = ["action": "listing_create", "printing": stock.key, "quantity": quantity, "unit_tokens": listingTokens]
                        Task { await model.mutate("market/listings", values) }
                    }) {
            HStack(alignment: .top, spacing: 18) {
                CardImageView(cardID: stock.cardID, hires: true, width: 150)
                VStack(alignment: .leading, spacing: 12) {
                    Text(OnlineText.cardName(stock.cardID)).font(Typography.title)
                    Text(OnlineText.l.sellableLine(finish: OnlineText.l.cardFinishName(stock.finish), available: stock.available))
                        .font(Typography.label).foregroundStyle(.secondary)
                    OnlineQuantity(value: $quantity, range: 1...min(1000, stock.available))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(OnlineText.l.pricePerCard).font(Typography.labelSemibold)
                        HStack(spacing: 6) {
                            TextField(OnlineText.l.priceLabel, value: $priceWon, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 120).monospacedDigit()
                            Text(OnlineText.l.wonUnit)
                        }
                        HStack(spacing: 6) {
                            priceChip(OnlineText.l.atMarketPrice, suggested)
                            priceChip(OnlineText.l.tenPercentLower, suggested * 9 / 10)
                            priceChip(OnlineText.l.tenPercentHigher, suggested * 11 / 10)
                        }
                        Text(stock.referenceWon.map { OnlineText.l.referenceStep(OnlineText.wonText($0)) } ?? OnlineText.l.noReferenceStep)
                            .font(Typography.caption).foregroundStyle(.secondary)
                        if listingTokens == nil {
                            Text(OnlineText.l.maximumPrice(OnlineText.wonText(OnlineText.maximumListingWon)))
                                .font(Typography.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .onAppear { if priceWon == 0 { priceWon = suggested } }
    }

    private func priceChip(_ title: String, _ won: Int) -> some View {
        let rounded = max(MarketEconomy.wonStep, (won / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        return Button(title) { priceWon = rounded }
            .buttonStyle(.bordered).controlSize(.regular).font(Typography.button)
    }
}

// MARK: - 교환

/// 교환 — 친구를 고르고, 줄 카드와 받을 카드를 그림으로 담는다.
@MainActor
struct OnlineTradingView: View {
    @Bindable var model: OnlineHubModel
    @State private var friend = ""
    @State private var offered: [String: Int] = [:]
    @State private var requested: [String: Int] = [:]
    @State private var pickingOffer = false
    @State private var pickingRequest = false
    @State private var confirming = false
    @State private var accepting: [String: Any]?
    @State private var preview: PrintingSelection?

    private var friends: [[String: Any]] { model.items("friends").filter { $0.string("status") == "accepted" } }

    /// 왜 보낼 수 없는지를 한 문장으로. 버튼만 꺼 두면 무엇을 고쳐야 하는지 모른다.
    private var blocker: String? {
        if friend.isEmpty { return OnlineText.l.tradePickFriend }
        if offered.isEmpty { return OnlineText.l.tradeAddOffer }
        if requested.isEmpty { return OnlineText.l.tradeAddRequest }
        if offered.count > 20 || requested.count > 20 { return OnlineText.l.tradeKindLimit }
        if offered.values.reduce(0, +) > 1000 || requested.values.reduce(0, +) > 1000 { return OnlineText.l.tradeCountLimit }
        if !Set(offered.keys).isDisjoint(with: requested.keys) { return OnlineText.l.tradeSameCard }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnlineSection(title: OnlineText.l.newTradeOffer, subtitle: OnlineText.l.newTradeOfferNote) {
                    if friends.isEmpty {
                        OnlineEmptyState(icon: "person.2", title: OnlineText.l.noFriendsYet,
                                         message: OnlineText.l.addFriendHint)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker(OnlineText.l.withWhom, selection: $friend) {
                                Text(OnlineText.l.chooseFriend).tag("")
                                ForEach(friends, id: \.onlineID) { Text($0.string("nickname")).tag($0.string("public_id")) }
                            }
                            .fixedSize()
                            tray(OnlineText.l.cardsIGive, lines: $offered) { pickingOffer = true }
                            tray(OnlineText.l.cardsIWant, lines: $requested) { pickingRequest = true }
                            HStack {
                                if let blocker {
                                    Text(blocker).font(Typography.label).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(OnlineText.l.sendOffer) { confirming = true }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!model.canWrite || blocker != nil)
                            }
                        }
                    }
                }

                let matches = model.items("matches")
                if !matches.isEmpty {
                    OnlineSection(title: OnlineText.l.mutualMatches, subtitle: OnlineText.l.mutualMatchesNote) {
                        VStack(spacing: 8) {
                            ForEach(matches, id: \.onlineID) { item in
                                HStack {
                                    Text(item.string("nickname")).font(Typography.bodySemibold)
                                    Text(OnlineText.l.matchSummary(give: (item["offered"] as? [Any])?.count ?? 0, get: (item["requested"] as? [Any])?.count ?? 0))
                                        .font(Typography.label).foregroundStyle(.secondary)
                                    Spacer()
                                    Button(OnlineText.l.draftFromMatch) { loadDraft(item) }.disabled(!model.canWrite)
                                }
                            }
                        }
                    }
                }

                let trades = model.items("trades")
                let waiting = trades.filter { $0.string("status") == "pending" && $0.bool("incoming") }
                if !waiting.isEmpty {
                    OnlineSection(title: OnlineText.l.offersToAnswer) {
                        VStack(spacing: 10) { ForEach(waiting, id: \.onlineID) { trade($0) } }
                    }
                }
                OnlineSection(title: OnlineText.l.tradeHistory) {
                    let rest = trades.filter { !($0.string("status") == "pending" && $0.bool("incoming")) }
                    if rest.isEmpty {
                        Text(OnlineText.l.noTradesYet).font(Typography.label).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) { ForEach(rest, id: \.onlineID) { trade($0) } }
                        OnlinePagination(model: model, key: "trades")
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .onAppear { if let draft = model.tradeDraft { loadDraft(draft); model.tradeDraft = nil } }
        .sheet(isPresented: $pickingOffer) {
            OnlineStockPicker(wallet: model.wallet, title: OnlineText.l.addCardsToGive, actionTitle: OnlineText.l.addAction,
                              alreadyPicked: offered) { key, quantity in offered[key, default: 0] += quantity }
        }
        .sheet(isPresented: $pickingRequest) {
            OnlineCatalogueSearch(title: OnlineText.l.addCardsWanted, actionTitle: OnlineText.l.addAction) { cardID, finish, quantity in
                guard let finish else { return }
                requested[CardPrintingKey(cardID: cardID, finish: finish).storageKey, default: 0] += quantity
            }
        }
        .sheet(isPresented: $confirming) {
            OnlineSheet(title: OnlineText.l.confirmOffer, actionTitle: OnlineText.l.sendOffer,
                        actionDisabled: !model.canWrite || blocker != nil,
                        note: OnlineText.l.confirmOfferNote,
                        action: {
                            // 보낼 카드는 누르는 순간 정한다. Task 본문은 이 블록이 끝난 뒤에 돌아서,
                            // 그 안에서 바구니를 읽으면 이미 비운 빈 바구니가 나가 서버가
                            // both_sides_required 로 거절했다. 바구니는 성공했을 때만 비운다.
                            let values: [String: Any] = ["action": "trade_create", "target_id": friend, "offered": lines(offered), "requested": lines(requested)]
                            Task { if await model.mutate("trades", values) { offered = [:]; requested = [:] } }
                        }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.l.toFriend(friendName(friend))).font(Typography.bodySemibold)
                    Text(OnlineText.l.cardsIGive).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: offered)
                    Text(OnlineText.l.cardsIGet).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: requested)
                }
            }
        }
        .sheet(item: Binding(get: { accepting.map(ListingBox.init) }, set: { accepting = $0?.item })) { box in
            let item = box.item
            OnlineSheet(title: OnlineText.l.acceptTradeQuestion, actionTitle: OnlineText.l.acceptAction,
                        actionDisabled: !model.canWrite,
                        note: OnlineText.l.acceptTradeNote,
                        action: { act("trade_accept", item) }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.l.tradeWith(item.string("nickname"))).font(Typography.bodySemibold)
                    Text(OnlineText.l.cardsIGive).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: item["requested"] as? [String: Int] ?? [:])
                    Text(OnlineText.l.cardsIGet).font(Typography.labelSemibold)
                    OnlineCardStrip(lines: item["offered"] as? [String: Int] ?? [:])
                }
            }
        }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    private func tray(_ title: String, lines: Binding<[String: Int]>, add: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(Typography.labelSemibold)
                Text(OnlineText.l.trayCount(kinds: lines.wrappedValue.count, cards: lines.wrappedValue.values.reduce(0, +)))
                    .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button { add() } label: { Label(OnlineText.l.addCards, systemImage: "plus") }
                    .disabled(lines.wrappedValue.count >= 20)
            }
            if lines.wrappedValue.isEmpty {
                Text(OnlineText.l.trayEmpty).font(Typography.label).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            } else {
                OnlineCardStrip(lines: lines.wrappedValue,
                                onRemove: { lines.wrappedValue[$0] = nil },
                                onOpen: { preview = PrintingSelection(id: $0) })
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func trade(_ item: [String: Any]) -> some View {
        let status = OnlineText.tradeStatus(item.string("status"))
        let incoming = item.bool("incoming")
        let theyGive = item["offered"] as? [String: Int] ?? [:]
        let iGive = item["requested"] as? [String: Int] ?? [:]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(incoming ? OnlineText.l.offerFrom(item.string("nickname")) : OnlineText.l.offerTo(item.string("nickname")))
                    .font(Typography.bodySemibold)
                OnlineBadge(text: status.text, color: status.color)
                Spacer()
                if item.string("status") == "pending" {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(OnlineText.l.cardsIGive).font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? iGive : theyGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(OnlineText.l.cardsIGet).font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? theyGive : iGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                }
            }
            if item.string("status") == "pending" {
                HStack {
                    Spacer()
                    if incoming {
                        Button(OnlineText.l.declineAction) { act("trade_reject", item) }
                        Button(OnlineText.l.acceptAction) { accepting = item }.buttonStyle(.borderedProminent)
                    } else {
                        Button(OnlineText.l.cancelOffer) { act("trade_cancel", item) }
                    }
                }
                .disabled(!model.canWrite)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func friendName(_ id: String) -> String {
        friends.first { $0.string("public_id") == id }?.string("nickname") ?? OnlineText.l.friendFallback
    }
    private func lines(_ values: [String: Int]) -> [[String: Any]] { values.keys.sorted().map { ["printing": $0, "quantity": values[$0] ?? 0] } }
    private func command(_ action: String, _ item: [String: Any]) -> [String: Any] { ["action": action, "target_id": item.string("id"), "target_version": item.int("version")] }
    private func act(_ action: String, _ item: [String: Any]) { Task { await model.mutate("trades", command(action, item)) } }
    private func loadDraft(_ item: [String: Any]) {
        friend = item.string("public_id")
        func basket(_ key: String) -> [String: Int] {
            var result: [String: Int] = [:]
            for line in (item[key] as? [[String: Any]] ?? []).prefix(20) {
                let remaining = 1000 - result.values.reduce(0, +)
                if remaining > 0 { result[line.string("printing")] = min(remaining, line.int("quantity")) }
            }
            return result
        }
        offered = basket("offered"); requested = basket("requested").filter { offered[$0.key] == nil }
    }
}
