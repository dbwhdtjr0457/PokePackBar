import SwiftUI

struct OnlineSocialView: View {
    @Bindable var model: OnlineHubModel
    @State private var nickname = ""
    @State private var code = ""
    @State private var collectionPublic = false
    @State private var wishlistPublic = false
    @State private var binderPublic = false
    @State private var draftLoaded = false
    @State private var cardID = ""
    @State private var finish = ""
    @State private var target = 1
    @State private var preview: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profile
                friends
                wishlist
                binder
                inventory
                matches
            }
        }
        .onAppear { loadDraft() }
        .onChange(of: model.generation) { loadDraft() }
        .sheet(item: Binding(get: { preview.map { PrintingSelection(id: $0) } }, set: { preview = $0?.id })) { selection in
            OnlinePrintingDetail(printing: selection.id)
        }
    }

    private var profile: some View {
        GroupBox("내 프로필 · 공개 범위") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("닉네임", text: $nickname)
                    Button("저장") { act("profile", ["action": "profile", "nickname": nickname,
                        "collection_public": collectionPublic, "wishlist_public": wishlistPublic, "binder_public": binderPublic]) }.disabled(!model.canWrite)
                }
                HStack {
                    Toggle("컬렉션 친구 공개", isOn: $collectionPublic)
                    Toggle("위시리스트 친구 공개", isOn: $wishlistPublic)
                    Toggle("바인더 친구 공개", isOn: $binderPublic)
                }
                HStack {
                    Text("친구 코드: \(model.profile.string("friend_code"))").textSelection(.enabled).monospaced()
                    Button("코드 재발급") { act("profile", ["action": "rotate_code"]) }.disabled(!model.canWrite)
                }
                Text("이메일·잔액·사용량·개봉 이력은 친구에게 공개하지 않습니다.").font(.caption).foregroundStyle(.secondary)
            }.padding(6)
        }
    }

    private var friends: some View {
        GroupBox("친구") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("친구 코드", text: $code)
                    Button("친구 요청") { act("friends", ["action": "friend_request", "friend_code": code]) }.disabled(!model.canWrite || code.isEmpty)
                }
                ForEach(model.items("friends"), id: \.onlineID) { item in
                    HStack {
                        Text(item.string("nickname")); Text(item.string("status")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if item.string("status") == "pending", item.bool("incoming") {
                            actionButton("수락", "friend_accept", item)
                            actionButton("거절", "friend_reject", item)
                        }
                        if item.string("status") == "accepted" {
                            Button("바인더 보기") { model.documents["friend"] = nil; model.documents["friendInventory"] = nil; model.selectedFriend = item.string("public_id"); Task { await model.refresh() } }
                        }
                        actionButton("친구 삭제", "friend_remove", item)
                        Button("차단") { act("friends", ["action": "block", "target_id": item.string("public_id")]) }.disabled(!model.canWrite)
                    }
                }
                if model.items("friends").isEmpty { Text("친구 코드를 입력해 요청을 보내세요. 요청은 상대가 수락해야 연결됩니다.").foregroundStyle(.secondary) }
                if let friend = model.documents["friend"], !model.selectedFriend.isEmpty {
                    Divider()
                    HStack { Text("\(friend.string("nickname"))의 공개 바인더").font(.headline); Spacer(); Button("닫기") { model.selectedFriend = ""; model.documents["friend"] = nil } }
                    if !friend.bool("binder_public") { Text("친구가 바인더를 공개하지 않았습니다.") }
                    printingGrid(friend["binder"] as? [String] ?? [])
                    if friend.bool("wishlist_public") {
                        ForEach(Array((friend["wishlist"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, wish in
                            Text("위시: \(name(wish.string("card_id"))) · \(wish.string("finish")) · 부족 \(wish.int("missing"))장")
                        }
                    }
                    if friend.bool("collection_public") {
                        Button("공개 컬렉션 보기") {
                            Task {
                                do { model.documents["friendInventory"] = try await model.read("v1/inventory?target=\(model.selectedFriend)&offset=0") }
                                catch { model.message = error.localizedDescription }
                            }
                        }
                        ForEach(model.items("friendInventory"), id: \.onlineID) { item in
                            Button("\(item.string("name_ko")) · \(item.string("finish")) · \(item.int("quantity"))장") { preview = item.string("printing") }
                        }
                        if let next = model.documents["friendInventory"]?["next_offset"] as? Int {
                            Button("친구 컬렉션 다음") { Task {
                                do { model.documents["friendInventory"] = try await model.read("v1/inventory?target=\(model.selectedFriend)&offset=\(next)") }
                                catch { model.message = error.localizedDescription }
                            } }
                        }
                    }
                }
                ForEach(model.items("blocks"), id: \.onlineID) { item in
                    HStack { Text("차단: \(item.string("nickname"))"); Button("차단 해제") { act("friends", ["action": "unblock", "target_id": item.string("public_id")]) }.disabled(!model.canWrite) }
                }
            }.padding(6)
        }
    }

    private var wishlist: some View {
        GroupBox("위시리스트") {
            VStack(alignment: .leading, spacing: 10) {
                OnlineCardPicker(cardID: $cardID, finish: $finish, allowsAny: true)
                HStack {
                    TextField("목표 장수", value: $target, format: .number).frame(width: 100)
                    Button("위시 추가") {
                        var wishes = model.profile["wishlist"] as? [[String: Any]] ?? []
                        wishes = wishes.map { wish in ["card_id": wish.string("card_id"), "finish": wish["finish"] ?? NSNull(), "target": wish.int("target")] }
                        wishes.append(["card_id": cardID, "finish": finish.isEmpty ? NSNull() : finish as Any, "target": target])
                        act("wishlist", ["action": "wishlist", "wishes": wishes])
                    }.disabled(!model.canWrite || cardID.isEmpty || !(1...1000).contains(target))
                }
                let wishes = model.profile["wishlist"] as? [[String: Any]] ?? []
                ForEach(Array(wishes.enumerated()), id: \.offset) { position, wish in
                    HStack {
                        Text(name(wish.string("card_id"))); Text(wish.string("finish").isEmpty ? "모든 판형" : wish.string("finish"))
                        Text("\(wish.int("owned"))/\(wish.int("target"))장 · 부족 \(wish.int("missing"))장")
                        Spacer()
                        Button("삭제") {
                            let next = wishes.enumerated().filter { $0.offset != position }.map { _, w in ["card_id": w.string("card_id"), "finish": w["finish"] ?? NSNull(), "target": w.int("target")] as [String: Any] }
                            act("wishlist", ["action": "wishlist", "wishes": next])
                        }.disabled(!model.canWrite)
                    }
                }
            }.padding(6)
        }
    }

    private var binder: some View {
        GroupBox("내 바인더 · 최대 36칸") {
            let keys = model.profile["binder"] as? [String] ?? []
            VStack(alignment: .leading) {
                printingGrid(keys)
                ForEach(Array(keys.enumerated()), id: \.offset) { i, key in
                    HStack {
                        Text("\(i + 1). \(printingName(key))")
                        Spacer()
                        Button("위로") { var next = keys; next.swapAt(i, i - 1); act("binder", ["action": "binder", "binder": next]) }.disabled(!model.canWrite || i == 0)
                        Button("빼기") { var next = keys; next.remove(at: i); act("binder", ["action": "binder", "binder": next]) }.disabled(!model.canWrite)
                    }
                }
                if keys.isEmpty { Text("아래 보유 카드 목록에서 ‘바인더에 추가’를 선택하세요.").foregroundStyle(.secondary) }
            }.padding(6)
        }
    }

    private var inventory: some View {
        GroupBox("보유 카드 · 예약된 카드는 거래/분해 불가") {
            VStack(alignment: .leading, spacing: 8) {
                HStack { TextField("한글·영문 이름 검색", text: $model.search); Button("검색") { model.offset = 0; Task { await model.refresh() } } }
                ForEach(model.items("inventory"), id: \.onlineID) { item in
                    HStack {
                        Button("\(item.string("name_ko")) · \(item.string("finish"))") { preview = item.string("printing") }
                        Text("보유 \(item.int("quantity")) · 예약 \(item.int("reserved")) · 거래 가능 \(item.int("available"))")
                        Spacer()
                        Button("바인더에 추가") {
                            var keys = model.profile["binder"] as? [String] ?? []
                            keys.append(item.string("printing"))
                            act("binder", ["action": "binder", "binder": keys])
                        }.disabled(!model.canWrite || (model.profile["binder"] as? [String] ?? []).count >= 36)
                    }
                }
                HStack {
                    Button("이전") { model.offset = max(0, model.offset - 50); Task { await model.refresh() } }.disabled(model.offset == 0)
                    Button("다음") { model.offset += 50; Task { await model.refresh() } }.disabled(model.documents["inventory"]?["next_offset"] as? Int == nil)
                }
            }.padding(6)
        }
    }

    private var matches: some View {
        GroupBox("서로 필요한 카드 · 교환 후보") {
            VStack(alignment: .leading) {
                if model.items("matches").isEmpty { Text("양쪽 위시리스트를 친구 공개로 설정하고 필요한 카드와 중복 카드가 있으면 추천합니다.").foregroundStyle(.secondary) }
                ForEach(model.items("matches"), id: \.onlineID) { item in
                    HStack {
                        Text("\(item.string("nickname")) · 줄 수 있는 \((item["offered"] as? [Any])?.count ?? 0)종 / 받을 수 있는 \((item["requested"] as? [Any])?.count ?? 0)종")
                        Button("교환안 만들기") { model.tradeDraft = item; model.section = "교환" }
                    }
                }
            }.padding(6)
        }
    }

    private func printingGrid(_ keys: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: 12) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Button { preview = key } label: {
                    VStack { OnlinePrintingArt(printing: key, width: 110); Text(printingName(key)).font(.caption).lineLimit(2) }
                }.buttonStyle(.plain)
            }
        }
    }
    private func loadDraft() {
        guard !draftLoaded, !model.profile.isEmpty else { return }
        nickname = model.profile.string("nickname")
        collectionPublic = model.profile.bool("collection_public")
        wishlistPublic = model.profile.bool("wishlist_public")
        binderPublic = model.profile.bool("binder_public")
        draftLoaded = true
    }
    private func actionButton(_ title: String, _ action: String, _ item: [String: Any]) -> some View {
        Button(title) { act("friends", ["action": action, "target_id": item.string("id"), "target_version": item.int("version")]) }.disabled(!model.canWrite)
    }
    private func act(_ route: String, _ values: [String: Any]) { Task { await model.mutate(route, values) } }
    private func name(_ id: String) -> String { CardIndex.shared?.card(id)?.displayName(.ko) ?? id }
    private func printingName(_ key: String) -> String { let p = CardPrintingKey(storageKey: key); return "\(name(p.cardID)) · \(p.finish.rawValue)" }
}

struct PrintingSelection: Identifiable { let id: String }

struct OnlinePrintingArt: View {
    let printing: String
    var width: CGFloat = 180
    var body: some View {
        let key = CardPrintingKey(storageKey: printing)
        if let card = CardIndex.shared?.card(key.cardID) {
            HolographicCardView(cardID: card.id, tier: card.tier, finish: key.finish, setID: card.setID,
                                originalRarity: card.rarity, width: width)
        } else { Image(systemName: "rectangle.portrait").frame(width: width, height: width / 0.717) }
    }
}

struct OnlinePrintingDetail: View {
    let printing: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 14) {
            let key = CardPrintingKey(storageKey: printing)
            Text(CardIndex.shared?.card(key.cardID)?.displayName(.ko) ?? key.cardID).font(.title2)
            OnlinePrintingArt(printing: printing, width: 280)
            Text(key.finish.rawValue)
            if let prices = CardPrices.shared {
                Text("참고 시세 $\(prices.price(key) ?? 0, specifier: "%.2f") · \(prices.sourceDate(cardID: key.cardID, finish: key.finish))")
                Text(prices.isReference(cardID: key.cardID, finish: key.finish) ? "실거래 기반 참고가" : "시장가")
                if let source = prices.sourceURL(cardID: key.cardID, finish: key.finish), let url = URL(string: source), ["https", "http"].contains(url.scheme) {
                    Link("가격 출처 보기", destination: url)
                }
            }
            Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
        }.padding(24)
    }
}

struct OnlineCardPicker: View {
    @Binding var cardID: String
    @Binding var finish: String
    var allowsAny = false
    @State private var query = ""
    private var candidates: [CardEntry] {
        guard !query.isEmpty else { return Array((CardIndex.shared?.cards ?? []).prefix(60)) }
        return Array((CardIndex.shared?.cards ?? []).filter { $0.name.localizedCaseInsensitiveContains(query) || ($0.nameKo ?? "").localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }.prefix(100))
    }
    var body: some View {
        HStack {
            TextField("카드 이름 검색", text: $query).frame(maxWidth: 220)
            Picker("카드", selection: $cardID) {
                Text("카드 선택").tag("")
                if !cardID.isEmpty, !candidates.contains(where: { $0.id == cardID }), let card = CardIndex.shared?.card(cardID) { Text("\(card.displayName(.ko)) · \(card.id)").tag(card.id) }
                ForEach(candidates) { Text("\($0.displayName(.ko)) · \($0.id)").tag($0.id) }
            }
            Picker("판형", selection: $finish) {
                Text(allowsAny ? "모든 판형" : "판형 선택").tag("")
                ForEach(CardFinish.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
            }.frame(maxWidth: 180)
        }
    }
}
