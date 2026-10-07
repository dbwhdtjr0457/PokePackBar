import SwiftUI

// MARK: - 마켓

/// 마켓 — 사기, 팔기, 내 판매.
///
/// 예전 화면은 등록 폼, 검색, 장부, 글 목록을 한 화면에 쌓고, 전체 카드 목록에서 고른 뒤에야
/// 「거래 가능 0장」을 알려 줬다. 지금은 할 일마다 화면을 나누고, 팔 수 있는 카드만 보여 준다.
/// 서버 경로와 보내는 값은 그대로다.
struct OnlineMarketView: View {
    @Bindable var model: OnlineHubModel
    @State private var mode: Mode = .buy
    @State private var buying: [String: Any]?
    @State private var selling: OnlineStock?
    @State private var sellQuery = ""
    @State private var preview: PrintingSelection?

    enum Mode: String, CaseIterable, Identifiable {
        case buy = "사기", sell = "팔기", mine = "내 판매"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
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
                TextField("카드 이름으로 찾기", text: $model.search)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    .onSubmit { reload() }
                Picker("세트", selection: $model.marketSet) {
                    Text("모든 세트").tag("")
                    ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) }
                }
                .fixedSize()
                Picker("등급", selection: $model.marketTier) {
                    Text("모든 등급").tag("")
                    ForEach(CardIndex.shared?.presentTiers ?? [], id: \.self) { tier in
                        Text("\(tier.rawValue) \(OnlineText.l.tierName(tier))").tag(tier.rawValue)
                    }
                }
                .fixedSize()
                Picker("정렬", selection: $model.marketSort) {
                    Text("새로 올라온 순").tag("newest")
                    Text("가격순").tag("price")
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
                                     title: hasFilter ? "조건에 맞는 카드가 없어요" : "아직 올라온 카드가 없어요",
                                     message: hasFilter ? "찾는 조건을 줄여 보세요." : "다른 사람이 카드를 올리면 여기에 나타나요.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16)], alignment: .leading, spacing: 18) {
                        ForEach(listings, id: \.onlineID) { item in
                            let printing = CardPrintingKey(storageKey: item.string("printing"))
                            Button { item.bool("mine") ? (preview = PrintingSelection(id: item.string("printing"))) : (buying = item) } label: {
                                OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue,
                                               badge: item.bool("mine") ? ("내 판매", .accentColor) : nil) {
                                    Text(OnlineText.won(tokens: item.int("unit_tokens")))
                                        .font(Typography.bodySemibold).monospacedDigit()
                                    Text("\(item.string("nickname")), \(item.int("quantity"))장")
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
            DexCardSearch.normalized(OnlineText.cardName($0.cardID)).contains(needle)
                || DexCardSearch.normalized(CardIndex.shared?.card($0.cardID)?.name ?? "").contains(needle)
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("내 카드에서 찾기", text: $sellQuery)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                Spacer()
                Text("같은 카드가 2장 이상일 때 남는 만큼 팔 수 있어요. 수수료는 없어요.")
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            ScrollView {
                if stock.isEmpty {
                    OnlineEmptyState(icon: "square.stack",
                                     title: sellQuery.isEmpty ? "팔 수 있는 카드가 없어요" : "맞는 카드가 없어요",
                                     message: sellQuery.isEmpty ? "같은 카드를 2장 이상 가지고 있으면 여기에 나타나요. 한 장은 늘 남겨 둬요." : nil)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 16)], alignment: .leading, spacing: 18) {
                        ForEach(stock) { item in
                            Button { selling = item } label: {
                                OnlineCardTile(cardID: item.cardID, finish: item.finish.rawValue) {
                                    Text("\(item.available)장 팔 수 있어요")
                                        .font(Typography.caption).foregroundStyle(.secondary)
                                    if let won = item.referenceWon {
                                        Text("시세 \(OnlineText.wonText(won))")
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
                Label("번 돈 \(OnlineText.won(tokens: model.wallet.state.marketEarnedTokens))", systemImage: "arrow.down.circle")
                Label("쓴 돈 \(OnlineText.won(tokens: model.wallet.state.marketSpentTokens))", systemImage: "arrow.up.circle")
            }
            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
            ScrollView {
                if listings.isEmpty {
                    OnlineEmptyState(icon: "tag", title: "올린 카드가 없어요",
                                     message: "「팔기」에서 남는 카드를 올려 보세요.")
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
                Text("\(OnlineText.l.cardFinishName(printing.finish)), 장당 \(OnlineText.won(tokens: item.int("unit_tokens"))), \(item.int("quantity"))장 남음")
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                if item.string("status") == "active" {
                    Text(OnlineText.remaining(until: item.int("expires_at")))
                        .font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.string("status") == "active", item.bool("mine") {
                Button("판매 내리기") {
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
        OnlineSheet(title: "카드 사기", actionTitle: "\(OnlineText.won(tokens: total))에 사기",
                    actionDisabled: !model.canWrite || !canAfford || affordable < 1,
                    note: "판매자가 그새 수량을 바꾸면 결제하지 않고 다시 확인해 달라고 알려 드려요.",
                    action: {
                        Task { await model.mutate("market/listings", ["action": "listing_buy", "target_id": item.string("id"), "target_version": item.int("version"), "quantity": quantity, "unit_tokens": unit]) }
                    }) {
            HStack(alignment: .top, spacing: 18) {
                CardImageView(cardID: printing.cardID, hires: true, width: 150)
                VStack(alignment: .leading, spacing: 10) {
                    Text(OnlineText.cardName(printing.cardID)).font(Typography.title)
                    Text("\(OnlineText.l.cardFinishName(printing.finish)), 판매자 \(item.string("nickname"))")
                        .font(Typography.label).foregroundStyle(.secondary)
                    Text("장당 \(OnlineText.won(tokens: unit))").font(Typography.bodySemibold).monospacedDigit()
                    if let reference = OnlineText.referenceWon(item.string("printing")) {
                        Text("참고 시세 \(OnlineText.wonText(reference))")
                            .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                    }
                    OnlineQuantity(value: $quantity, range: 1...maximum)
                    Text(affordable < 1 ? "잔액이 부족해요" : "사고 나면 \(OnlineText.won(tokens: max(0, model.wallet.availableTokens - total))) 남아요")
                        .font(Typography.label).foregroundStyle(affordable < 1 ? Color.orange : Color.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

private struct SellSheet: View {
    @Bindable var model: OnlineHubModel
    let stock: OnlineStock
    @State private var quantity = 1
    @State private var priceWon = 0

    var body: some View {
        let suggested = stock.referenceWon ?? MarketEconomy.wonStep
        let price = max(MarketEconomy.wonStep, (priceWon / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        OnlineSheet(title: "카드 팔기", actionTitle: "판매 올리기",
                    actionDisabled: !model.canWrite || priceWon < MarketEconomy.wonStep,
                    note: "\(quantity)장을 장당 \(OnlineText.wonText(price))에 올려요. 7일 동안 안 팔린 카드는 자동으로 돌아와요. 시세가 바뀌어도 가격은 그대로예요.",
                    action: {
                        Task { await model.mutate("market/listings", ["action": "listing_create", "printing": stock.key, "quantity": quantity, "unit_tokens": OnlineText.tokens(won: price)]) }
                    }) {
            HStack(alignment: .top, spacing: 18) {
                CardImageView(cardID: stock.cardID, hires: true, width: 150)
                VStack(alignment: .leading, spacing: 12) {
                    Text(OnlineText.cardName(stock.cardID)).font(Typography.title)
                    Text("\(OnlineText.l.cardFinishName(stock.finish)), \(stock.available)장 팔 수 있어요")
                        .font(Typography.label).foregroundStyle(.secondary)
                    OnlineQuantity(value: $quantity, range: 1...min(1000, stock.available))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("장당 가격").font(Typography.labelSemibold)
                        HStack(spacing: 6) {
                            TextField("가격", value: $priceWon, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 120).monospacedDigit()
                            Text("원")
                        }
                        HStack(spacing: 6) {
                            priceChip("시세대로", suggested)
                            priceChip("10% 싸게", suggested * 9 / 10)
                            priceChip("10% 비싸게", suggested * 11 / 10)
                        }
                        Text(stock.referenceWon.map { "참고 시세 \(OnlineText.wonText($0)), 100원 단위로 올라가요" } ?? "참고 시세가 없어요. 100원 단위로 올라가요")
                            .font(Typography.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { if priceWon == 0 { priceWon = suggested } }
    }

    private func priceChip(_ title: String, _ won: Int) -> some View {
        let rounded = max(MarketEconomy.wonStep, (won / MarketEconomy.wonStep) * MarketEconomy.wonStep)
        return Button(title) { priceWon = rounded }
            .buttonStyle(.bordered).controlSize(.small)
    }
}

// MARK: - 교환

/// 교환 — 친구를 고르고, 줄 카드와 받을 카드를 그림으로 담는다.
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
        if friend.isEmpty { return "교환할 친구를 고르세요." }
        if offered.isEmpty { return "내가 줄 카드를 한 장 이상 담으세요." }
        if requested.isEmpty { return "받고 싶은 카드를 한 장 이상 담으세요." }
        if offered.count > 20 || requested.count > 20 { return "한쪽에 담을 수 있는 카드는 20종까지예요." }
        if offered.values.reduce(0, +) > 1000 || requested.values.reduce(0, +) > 1000 { return "한쪽에 담을 수 있는 카드는 1,000장까지예요." }
        if !Set(offered.keys).isDisjoint(with: requested.keys) { return "같은 카드를 주고받을 수는 없어요." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnlineSection(title: "새 교환 제안", subtitle: "친구가 72시간 안에 수락하면 바로 바뀌어요. 그동안 내가 줄 카드는 묶여 있어요.") {
                    if friends.isEmpty {
                        OnlineEmptyState(icon: "person.2", title: "아직 친구가 없어요",
                                         message: "「친구」 탭에서 친구 코드로 신청해 보세요.")
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("누구와", selection: $friend) {
                                Text("친구 고르기").tag("")
                                ForEach(friends, id: \.onlineID) { Text($0.string("nickname")).tag($0.string("public_id")) }
                            }
                            .fixedSize()
                            tray("내가 줄 카드", lines: $offered) { pickingOffer = true }
                            tray("받고 싶은 카드", lines: $requested) { pickingRequest = true }
                            HStack {
                                if let blocker {
                                    Text(blocker).font(Typography.label).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("제안 보내기") { confirming = true }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!model.canWrite || blocker != nil)
                            }
                        }
                    }
                }

                let matches = model.items("matches")
                if !matches.isEmpty {
                    OnlineSection(title: "서로 필요한 카드가 있어요", subtitle: "위시리스트를 보고 맞춰 봤어요.") {
                        VStack(spacing: 8) {
                            ForEach(matches, id: \.onlineID) { item in
                                HStack {
                                    Text(item.string("nickname")).font(Typography.bodySemibold)
                                    Text("줄 수 있는 카드 \((item["offered"] as? [Any])?.count ?? 0)종, 받을 수 있는 카드 \((item["requested"] as? [Any])?.count ?? 0)종")
                                        .font(Typography.label).foregroundStyle(.secondary)
                                    Spacer()
                                    Button("이걸로 제안 만들기") { loadDraft(item) }.disabled(!model.canWrite)
                                }
                            }
                        }
                    }
                }

                let trades = model.items("trades")
                let waiting = trades.filter { $0.string("status") == "pending" && $0.bool("incoming") }
                if !waiting.isEmpty {
                    OnlineSection(title: "답해야 할 제안") {
                        VStack(spacing: 10) { ForEach(waiting, id: \.onlineID) { trade($0) } }
                    }
                }
                OnlineSection(title: "교환 기록") {
                    let rest = trades.filter { !($0.string("status") == "pending" && $0.bool("incoming")) }
                    if rest.isEmpty {
                        Text("아직 교환한 적이 없어요.").font(Typography.label).foregroundStyle(.secondary)
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
            OnlineStockPicker(wallet: model.wallet, title: "내가 줄 카드 담기", actionTitle: "담기",
                              alreadyPicked: offered) { key, quantity in offered[key, default: 0] += quantity }
        }
        .sheet(isPresented: $pickingRequest) {
            OnlineCatalogueSearch(title: "받고 싶은 카드 담기", actionTitle: "담기") { cardID, finish, quantity in
                guard let finish else { return }
                requested[CardPrintingKey(cardID: cardID, finish: finish).storageKey, default: 0] += quantity
            }
        }
        .sheet(isPresented: $confirming) {
            OnlineSheet(title: "이렇게 제안할까요?", actionTitle: "제안 보내기",
                        actionDisabled: !model.canWrite || blocker != nil,
                        note: "친구가 수락할 때 서버가 양쪽 카드를 다시 확인해요. 72시간이 지나면 제안은 사라지고 카드는 풀려요.",
                        action: {
                            Task { await model.mutate("trades", ["action": "trade_create", "target_id": friend, "offered": lines(offered), "requested": lines(requested)]) }
                            offered = [:]; requested = [:]
                        }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(friendName(friend))님에게").font(Typography.bodySemibold)
                    Text("내가 줄 카드").font(Typography.labelSemibold)
                    OnlineCardStrip(lines: offered)
                    Text("받을 카드").font(Typography.labelSemibold)
                    OnlineCardStrip(lines: requested)
                }
            }
        }
        .sheet(item: Binding(get: { accepting.map(ListingBox.init) }, set: { accepting = $0?.item })) { box in
            let item = box.item
            OnlineSheet(title: "교환을 수락할까요?", actionTitle: "수락하기",
                        actionDisabled: !model.canWrite,
                        note: "수락하면 바로 카드가 바뀌어요.",
                        action: { act("trade_accept", item) }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(item.string("nickname"))님과의 교환").font(Typography.bodySemibold)
                    Text("내가 줄 카드").font(Typography.labelSemibold)
                    OnlineCardStrip(lines: item["requested"] as? [String: Int] ?? [:])
                    Text("받을 카드").font(Typography.labelSemibold)
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
                Text("\(lines.wrappedValue.count)종, \(lines.wrappedValue.values.reduce(0, +))장")
                    .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Button { add() } label: { Label("카드 담기", systemImage: "plus") }
                    .disabled(lines.wrappedValue.count >= 20)
            }
            if lines.wrappedValue.isEmpty {
                Text("아직 담은 카드가 없어요.").font(Typography.label).foregroundStyle(.secondary)
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
                Text(incoming ? "\(item.string("nickname"))님이 보낸 제안" : "\(item.string("nickname"))님에게 보낸 제안")
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
                    Text("내가 줄 카드").font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? iGive : theyGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("받을 카드").font(Typography.caption).foregroundStyle(.secondary)
                    OnlineCardStrip(lines: incoming ? theyGive : iGive, width: 52, onOpen: { preview = PrintingSelection(id: $0) })
                }
            }
            if item.string("status") == "pending" {
                HStack {
                    Spacer()
                    if incoming {
                        Button("거절") { act("trade_reject", item) }
                        Button("수락하기") { accepting = item }.buttonStyle(.borderedProminent)
                    } else {
                        Button("제안 취소") { act("trade_cancel", item) }
                    }
                }
                .disabled(!model.canWrite)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func friendName(_ id: String) -> String {
        friends.first { $0.string("public_id") == id }?.string("nickname") ?? "친구"
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
