import SwiftUI

private func printingTitle(_ value: String) -> String {
    let key = CardPrintingKey(storageKey: value)
    return "\(CardIndex.shared?.card(key.cardID)?.displayName(.ko) ?? key.cardID) · \(key.finish.rawValue) · \(key.cardID)"
}

private func expiryText(_ item: [String: Any]) -> String {
    Date(timeIntervalSince1970: Double(item.int("expires_at"))).formatted()
}

private struct OnlineConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let route: String
    let payload: [String: Any]
}

private struct ConfirmationSheet: View {
    @Bindable var model: OnlineHubModel
    let value: OnlineConfirmation
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(value.title).font(.title2.bold())
            ScrollView { Text(value.detail).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 360)
            Text("서버에서 수량과 버전을 다시 확인합니다. 조건이 달라지면 거래하지 않고 재확인을 요청합니다.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("확인 후 실행") {
                    dismiss()
                    Task { await model.mutate(value.route, value.payload) }
                }.disabled(!model.canWrite)
            }
        }.padding(24).frame(width: 560)
    }
}

struct OnlineTradingView: View {
    @Bindable var model: OnlineHubModel
    @State private var friend = ""
    @State private var offered: [String: Int] = [:]
    @State private var requested: [String: Int] = [:]
    @State private var confirmation: OnlineConfirmation?
    @State private var preview: PrintingSelection?
    private var valid: Bool {
        !friend.isEmpty && !offered.isEmpty && !requested.isEmpty && offered.count <= 20 && requested.count <= 20
            && offered.values.reduce(0, +) <= 1000 && requested.values.reduce(0, +) <= 1000
            && Set(offered.keys).isDisjoint(with: requested.keys)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("교환 제안 · 양쪽 각각 최대 20종 / 1,000장") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("친구", selection: $friend) {
                            Text("친구 선택").tag("")
                            ForEach(model.items("friends").filter { $0.string("status") == "accepted" }, id: \.onlineID) { item in
                                Text(item.string("nickname")).tag(item.string("public_id"))
                            }
                        }
                        TradeBasket(title: "내가 보낼 카드", lines: $offered, wallet: model.wallet)
                        TradeBasket(title: "상대에게 요청할 카드", lines: $requested, wallet: nil)
                        Text("보내는 중복 카드는 즉시 예약됩니다. 상대 카드는 수락할 때 검증하며 72시간 후 만료됩니다.").font(.caption)
                        Button("교환안 확인") {
                            confirmation = OnlineConfirmation(title: "교환 제안 확인", detail: "보낼 카드\n\(description(offered))\n\n받을 카드\n\(description(requested))", route: "trades", payload: ["action": "trade_create", "target_id": friend, "offered": lines(offered), "requested": lines(requested)])
                        }.disabled(!model.canWrite || !valid)
                    }.padding(8)
                }
                ForEach(model.items("matches"), id: \.onlineID) { item in
                    Button("\(item.string("nickname")) · 서로 필요한 카드로 교환안 작성") { loadDraft(item) }.disabled(!model.canWrite)
                }
                Text("교환 내역").font(.headline)
                if model.items("trades").isEmpty { Text("아직 교환 내역이 없습니다.").foregroundStyle(.secondary) }
                ForEach(model.items("trades"), id: \.onlineID) { item in trade(item) }
                OnlinePagination(model: model, key: "trades")
            }
        }
        .onAppear { if let draft = model.tradeDraft { loadDraft(draft); model.tradeDraft = nil } }
        .sheet(item: $confirmation) { ConfirmationSheet(model: model, value: $0) }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    private func trade(_ item: [String: Any]) -> some View {
        GroupBox("\(item.string("nickname")) · \(item.string("status"))") {
            VStack(alignment: .leading, spacing: 8) {
                let give = item["offered"] as? [String: Int] ?? [:]
                let receive = item["requested"] as? [String: Int] ?? [:]
                Text(item.bool("incoming") ? "상대가 보내는 카드" : "내가 보내는 카드").font(.caption.bold())
                cardLines(give)
                Text(item.bool("incoming") ? "내가 보내야 하는 카드" : "상대에게 요청한 카드").font(.caption.bold())
                cardLines(receive)
                Text("만료: \(expiryText(item))").font(.caption).foregroundStyle(.secondary)
                if item.string("status") == "pending" {
                    HStack {
                        if item.bool("incoming") {
                            Button("수락 확인") {
                                confirmation = OnlineConfirmation(title: "교환 수락", detail: "보낼 카드\n\(description(receive))\n\n받을 카드\n\(description(give))", route: "trades", payload: command("trade_accept", item))
                            }
                            Button("거절") { act("trade_reject", item) }
                        } else { Button("제안 취소 · 예약 해제") { act("trade_cancel", item) } }
                    }.disabled(!model.canWrite)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }
    private func cardLines(_ values: [String: Int]) -> some View {
        ForEach(values.keys.sorted(), id: \.self) { key in
            Button("\(printingTitle(key)) × \(values[key] ?? 0)") { preview = PrintingSelection(id: key) }.buttonStyle(.plain)
        }
    }
    private func lines(_ values: [String: Int]) -> [[String: Any]] { values.keys.sorted().map { ["printing": $0, "quantity": values[$0] ?? 0] } }
    private func description(_ values: [String: Int]) -> String { values.keys.sorted().map { "\(printingTitle($0)) × \(values[$0] ?? 0)" }.joined(separator: "\n") }
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

private struct TradeBasket: View {
    let title: String
    @Binding var lines: [String: Int]
    let wallet: WalletStore?
    @State private var card = ""
    @State private var finish = ""
    @State private var quantity = 1
    private var key: String { "\(card)#\(finish)" }
    private var free: Int {
        guard let wallet else { return 1000 }
        return max(0, wallet.ownedPrintings(cardID: card).first { $0.printing.storageKey == key }?.count ?? 0) - (wallet.remote?.reservedPrintings[key] ?? 0) - 1
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            OnlineCardPicker(cardID: $card, finish: $finish)
            HStack {
                TextField("장수", value: $quantity, format: .number).frame(width: 90)
                if wallet != nil { Text("거래 가능 \(max(0, free))장").font(.caption) }
                Button("추가 / 수량 변경") { lines[key] = quantity }
                    .disabled(card.isEmpty || finish.isEmpty || quantity < 1 || quantity > min(1000, free) || (lines[key] == nil && lines.count >= 20) || lines.values.reduce(0, +) - (lines[key] ?? 0) + quantity > 1000)
            }
            ForEach(lines.keys.sorted(), id: \.self) { key in
                HStack { Text("\(printingTitle(key)) × \(lines[key] ?? 0)"); Spacer(); Button("빼기") { lines[key] = nil } }
            }
        }
    }
}

struct OnlineMarketView: View {
    @Bindable var model: OnlineHubModel
    @State private var card = ""
    @State private var finish = ""
    @State private var quantity = 1
    @State private var unitPrice = 1
    @State private var quantities: [String: Int] = [:]
    @State private var confirmation: OnlineConfirmation?
    @State private var preview: PrintingSelection?
    private var printing: String { "\(card)#\(finish)" }
    private var free: Int { max(0, (model.wallet.ownedPrintings(cardID: card).first { $0.printing.storageKey == printing }?.count ?? 0) - (model.remote?.reservedPrintings[printing] ?? 0) - 1) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("중복 카드 판매 등록 · 수수료 없음") {
                    VStack(alignment: .leading, spacing: 10) {
                        OnlineCardPicker(cardID: $card, finish: $finish)
                        HStack {
                            Text("수량"); TextField("수량", value: $quantity, format: .number).frame(width: 80)
                            Text("장당 토큰"); TextField("장당 토큰", value: $unitPrice, format: .number).frame(width: 130)
                            Text("거래 가능 \(free)장").font(.caption)
                            Spacer()
                            Button("등록 확인") {
                                confirmation = OnlineConfirmation(title: "판매 등록", detail: "\(printingTitle(printing))\n\(quantity)장 · 장당 \(unitPrice) 토큰\n\(reference(printing))\n남은 수량은 7일 후 자동 해제됩니다. 가격은 시세와 무관하게 고정됩니다.", route: "market/listings", payload: ["action": "listing_create", "printing": printing, "quantity": quantity, "unit_tokens": unitPrice])
                            }.disabled(!model.canWrite || card.isEmpty || finish.isEmpty || quantity < 1 || quantity > min(free, 1000) || unitPrice < 1 || unitPrice > 1_000_000_000_000)
                        }
                    }.padding(6)
                }
                HStack {
                    TextField("한글·영문 카드명", text: $model.search)
                    Toggle("내 판매 글", isOn: $model.ownListings)
                    Picker("정렬", selection: $model.marketSort) { Text("최신순").tag("newest"); Text("가격순").tag("price") }
                    Button("검색") { model.offset = 0; Task { await model.refresh() } }
                }
                HStack {
                    Picker("세트", selection: $model.marketSet) { Text("전체").tag(""); ForEach(CardIndex.shared?.sets ?? [], id: \.id) { Text($0.name).tag($0.id) } }
                    TextField("희귀도 (예: SAR)", text: $model.marketTier)
                    Picker("판형", selection: $model.marketFinish) { Text("전체").tag(""); ForEach(CardFinish.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                }
                Text("마켓 누적 수입 \(model.wallet.state.marketEarnedTokens) / 지출 \(model.wallet.state.marketSpentTokens) 토큰 · 분해 판매·수집량과 별도 장부").font(.caption)
                if model.items("listings").isEmpty { Text("조건에 맞는 판매 글이 없습니다.").foregroundStyle(.secondary) }
                ForEach(model.items("listings"), id: \.onlineID) { item in listing(item) }
                OnlinePagination(model: model, key: "listings")
            }
        }
        .sheet(item: $confirmation) { ConfirmationSheet(model: model, value: $0) }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }
    private func listing(_ item: [String: Any]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Button(printingTitle(item.string("printing"))) { preview = PrintingSelection(id: item.string("printing")) }.font(.headline).buttonStyle(.plain)
                Text("\(item.string("nickname")) · 남은 \(item.int("quantity"))장 · 장당 \(item.int("unit_tokens")) 토큰 · \(item.string("status"))")
                Text(reference(item.string("printing"))).font(.caption).foregroundStyle(.secondary)
                Text("만료: \(expiryText(item))").font(.caption)
                if item.string("status") == "active" {
                    if item.bool("mine") {
                        Button("판매 취소 · 남은 예약 해제") { Task { await model.mutate("market/listings", ["action": "listing_cancel", "target_id": item.string("id"), "target_version": item.int("version")]) } }.disabled(!model.canWrite)
                    } else {
                        HStack {
                            let id = item.string("id")
                            let count = quantities[id] ?? 1
                            TextField("구매 수량", value: Binding(get: { quantities[id] ?? 1 }, set: { quantities[id] = $0 }), format: .number).frame(width: 90)
                            Button("구매 확인") {
                                let total = count * item.int("unit_tokens")
                                confirmation = OnlineConfirmation(title: "마켓 구매 확인", detail: "\(printingTitle(item.string("printing")))\n수량 \(count)장 · 장당 \(item.int("unit_tokens")) 토큰\n총액 \(total) 토큰\n\(reference(item.string("printing")))\n재고가 바뀌면 수량을 줄여 자동 결제하지 않습니다.", route: "market/listings", payload: ["action": "listing_buy", "target_id": id, "target_version": item.int("version"), "quantity": count, "unit_tokens": item.int("unit_tokens")])
                            }.disabled(!model.canWrite || count < 1 || count > min(1000, item.int("quantity")) || (count > 0 && count <= 1000 && count * item.int("unit_tokens") > model.wallet.availableTokens))
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }
    private func reference(_ value: String) -> String {
        let key = CardPrintingKey(storageKey: value)
        guard let prices = CardPrices.shared, let usd = prices.price(key) else { return "참고 시세 없음" }
        return "참고가 $\(String(format: "%.2f", usd)) · \(prices.sourceDate(cardID: key.cardID, finish: key.finish)) · 게임 토큰 판매가와 별개"
    }
}

struct OnlinePagination: View {
    @Bindable var model: OnlineHubModel
    let key: String
    var body: some View {
        HStack {
            Button("이전") { model.offset = max(0, model.offset - 50); Task { await model.refresh() } }.disabled(model.offset == 0 || model.loading)
            Button("다음") { model.offset += 50; Task { await model.refresh() } }.disabled(model.documents[key]?["next_offset"] as? Int == nil || model.loading)
        }
    }
}
