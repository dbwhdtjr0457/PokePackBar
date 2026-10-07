import AppKit
import SwiftUI

/// 친구 — 내 프로필, 친구, 위시리스트, 바인더, 서버에 있는 내 카드.
///
/// 서버 경로와 보내는 값은 그대로 두고, 화면만 그림과 쉬운 말로 바꿨다.
@MainActor
struct OnlineSocialView: View {
    @Bindable var model: OnlineHubModel
    @State private var nickname = ""
    @State private var code = ""
    @State private var collectionPublic = false
    @State private var wishlistPublic = false
    @State private var binderPublic = false
    @State private var draftLoaded = false
    @State private var addingWish = false
    @State private var visitingFriend: String?
    @State private var preview: PrintingSelection?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                profile
                friends
                wishlist
                binder
                inventory
            }
            .padding(.bottom, 12)
        }
        .onAppear { loadDraft() }
        .onChange(of: model.generation) { loadDraft() }
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
        .sheet(isPresented: $addingWish) {
            OnlineCatalogueSearch(title: "위시리스트에 추가", actionTitle: "추가하기", allowsAnyFinish: true, maxQuantity: 1000) { cardID, finish, target in
                var wishes = currentWishes
                wishes.append(["card_id": cardID, "finish": finish.map { $0.rawValue as Any } ?? NSNull(), "target": target])
                act("wishlist", ["action": "wishlist", "wishes": wishes])
            }
        }
        .sheet(item: Binding(get: { visitingFriend.map(PrintingSelection.init) }, set: { visitingFriend = $0?.id })) { _ in
            FriendBinderSheet(model: model)
        }
    }

    // MARK: 내 프로필

    private var profile: some View {
        OnlineSection(title: "내 프로필", subtitle: "잔액, 사용량, 개봉 기록은 친구에게 보이지 않아요.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("닉네임").font(Typography.labelSemibold).frame(width: 64, alignment: .leading)
                    TextField("친구에게 보일 이름", text: $nickname).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    Button("저장") { saveProfile() }
                        .disabled(!model.canWrite || nickname.isEmpty || nickname == model.profile.string("nickname"))
                }
                HStack(spacing: 10) {
                    Text("친구 코드").font(Typography.labelSemibold).frame(width: 64, alignment: .leading)
                    Text(model.profile.string("friend_code"))
                        .font(.system(size: 15, weight: .medium, design: .monospaced)).textSelection(.enabled)
                    Button(copied ? "복사했어요" : "복사") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.profile.string("friend_code"), forType: .string)
                        copied = true
                    }
                    .disabled(model.profile.string("friend_code").isEmpty)
                    Button("새 코드 받기") { act("profile", ["action": "rotate_code"]) }
                        .buttonStyle(.borderless).disabled(!model.canWrite)
                        .help("예전 코드로는 더 이상 친구 신청을 받을 수 없어요.")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("친구에게 보여 줄 것").font(Typography.labelSemibold)
                    Toggle("내 컬렉션", isOn: $collectionPublic)
                    Toggle("위시리스트", isOn: $wishlistPublic)
                    Toggle("바인더", isOn: $binderPublic)
                }
                .onChange(of: collectionPublic) { if draftLoaded { saveProfile() } }
                .onChange(of: wishlistPublic) { if draftLoaded { saveProfile() } }
                .onChange(of: binderPublic) { if draftLoaded { saveProfile() } }
            }
        }
    }

    // MARK: 친구

    private var friends: some View {
        let items = model.items("friends")
        let incoming = items.filter { $0.string("status") == "pending" && $0.bool("incoming") }
        let outgoing = items.filter { $0.string("status") == "pending" && !$0.bool("incoming") }
        let accepted = items.filter { $0.string("status") == "accepted" }
        return OnlineSection(title: "친구") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("친구 코드 입력", text: $code).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                        .onSubmit(sendRequest)
                    Button("친구 신청", action: sendRequest).disabled(!model.canWrite || code.isEmpty)
                }
                ForEach(incoming, id: \.onlineID) { item in
                    friendRow(item, note: "나에게 친구 신청을 보냈어요") {
                        Button("거절") { friendAction("friend_reject", item) }
                        Button("수락") { friendAction("friend_accept", item) }.buttonStyle(.borderedProminent)
                    }
                }
                ForEach(accepted, id: \.onlineID) { item in
                    friendRow(item, note: nil) {
                        Button("바인더 보기") {
                            model.documents["friend"] = nil; model.documents["friendInventory"] = nil
                            model.selectedFriend = item.string("public_id")
                            visitingFriend = item.string("public_id")
                            Task { await model.refresh(full: false) }
                        }
                        Menu {
                            Button("친구 끊기") { friendAction("friend_remove", item) }
                            Button("차단하기", role: .destructive) { act("friends", ["action": "block", "target_id": item.string("public_id")]) }
                        } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).fixedSize()
                    }
                }
                ForEach(outgoing, id: \.onlineID) { item in
                    friendRow(item, note: "수락을 기다리는 중") {
                        Button("신청 취소") { friendAction("friend_remove", item) }
                    }
                }
                if items.isEmpty {
                    Text("친구 코드를 받아 신청해 보세요. 상대가 수락하면 서로 바인더를 보고 교환할 수 있어요.")
                        .font(Typography.label).foregroundStyle(.secondary)
                }
                let blocks = model.items("blocks")
                if !blocks.isEmpty {
                    DisclosureGroup("차단한 사용자 \(blocks.count)명") {
                        ForEach(blocks, id: \.onlineID) { item in
                            HStack {
                                Text(item.string("nickname"))
                                Spacer()
                                Button("차단 풀기") { act("friends", ["action": "unblock", "target_id": item.string("public_id")]) }
                                    .disabled(!model.canWrite)
                            }
                        }
                    }
                    .font(Typography.label)
                }
            }
        }
    }

    private func friendRow<Actions: View>(_ item: [String: Any], note: String?,
                                          @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle").font(.system(size: 22)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.string("nickname")).font(Typography.bodySemibold)
                if let note { Text(note).font(Typography.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            actions().disabled(!model.canWrite)
        }
        .padding(.vertical, 4)
    }

    // MARK: 위시리스트

    private var currentWishes: [[String: Any]] {
        (model.profile["wishlist"] as? [[String: Any]] ?? []).map { wish in
            ["card_id": wish.string("card_id"), "finish": wish["finish"] ?? NSNull(), "target": wish.int("target")]
        }
    }

    private var wishlist: some View {
        let wishes = model.profile["wishlist"] as? [[String: Any]] ?? []
        return OnlineSection(title: "위시리스트", subtitle: "갖고 싶은 카드를 적어 두면 마켓에 올라왔을 때 알려 드리고, 교환 상대도 찾아 드려요.") {
            Button { addingWish = true } label: { Label("카드 추가", systemImage: "plus") }
                .disabled(!model.canWrite)
        } content: {
            if wishes.isEmpty {
                Text("아직 적어 둔 카드가 없어요.").font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(Array(wishes.enumerated()), id: \.offset) { position, wish in
                        let finish = wish.string("finish")
                        OnlineCardTile(cardID: wish.string("card_id"), finish: finish, width: 104,
                                       badge: wish.int("missing") == 0 ? ("다 모았어요", .green) : nil) {
                            Text(finish.isEmpty ? "어떤 판형이든, \(wish.int("owned"))/\(wish.int("target"))장"
                                                : "\(wish.int("owned"))/\(wish.int("target"))장")
                                .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                            Button("빼기") {
                                let next = currentWishes.enumerated().filter { $0.offset != position }.map(\.element)
                                act("wishlist", ["action": "wishlist", "wishes": next])
                            }
                            .buttonStyle(.borderless).font(Typography.caption).disabled(!model.canWrite)
                        }
                    }
                }
            }
        }
    }

    // MARK: 바인더

    private var binder: some View {
        let keys = model.profile["binder"] as? [String] ?? []
        return OnlineSection(title: "내 바인더", subtitle: "친구에게 자랑할 카드를 최대 36장까지 골라 꽂아 두세요. 아래 「내 카드」에서 넣을 수 있어요.") {
            if keys.isEmpty {
                Text("아직 꽂은 카드가 없어요.").font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { i, key in
                        let printing = CardPrintingKey(storageKey: key)
                        OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 104) {
                            HStack(spacing: 8) {
                                Button { var next = keys; next.swapAt(i, i - 1); act("binder", ["action": "binder", "binder": next]) } label: {
                                    Image(systemName: "arrow.left")
                                }
                                .help("앞으로").disabled(!model.canWrite || i == 0)
                                Button("빼기") { var next = keys; next.remove(at: i); act("binder", ["action": "binder", "binder": next]) }
                                    .disabled(!model.canWrite)
                            }
                            .buttonStyle(.borderless).font(Typography.caption)
                        }
                        .onTapGesture { preview = PrintingSelection(id: key) }
                    }
                }
            }
        }
    }

    // MARK: 서버에 있는 내 카드

    private var inventory: some View {
        let binderKeys = model.profile["binder"] as? [String] ?? []
        let items = model.items("inventory")
        return OnlineSection(title: "내 카드", subtitle: "판매나 교환에 걸려 있는 카드는 그 거래가 끝날 때까지 쓸 수 없어요.") {
            TextField("이름으로 찾기", text: $model.search)
                .textFieldStyle(.roundedBorder).frame(width: 220)
                .onSubmit { model.offset = 0; Task { await model.refresh(full: false) } }
        } content: {
            if items.isEmpty {
                Text(model.search.isEmpty ? "서버에 올라간 카드가 아직 없어요." : "맞는 카드가 없어요.")
                    .font(Typography.label).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 14)], alignment: .leading, spacing: 16) {
                    ForEach(items, id: \.onlineID) { item in
                        let key = item.string("printing")
                        let printing = CardPrintingKey(storageKey: key)
                        OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 104) {
                            Text(item.int("reserved") > 0 ? "\(item.int("quantity"))장, \(item.int("reserved"))장 거래 중" : "\(item.int("quantity"))장")
                                .font(Typography.caption).foregroundStyle(.secondary).monospacedDigit()
                            if binderKeys.contains(key) {
                                Text("바인더에 있어요").font(Typography.caption).foregroundStyle(.secondary)
                            } else {
                                Button("바인더에 꽂기") { act("binder", ["action": "binder", "binder": binderKeys + [key]]) }
                                    .buttonStyle(.borderless).font(Typography.caption)
                                    .disabled(!model.canWrite || binderKeys.count >= 36)
                            }
                        }
                        .onTapGesture { preview = PrintingSelection(id: key) }
                    }
                }
                OnlinePagination(model: model, key: "inventory")
            }
        }
    }

    // MARK: 동작

    private func sendRequest() {
        guard !code.isEmpty else { return }
        act("friends", ["action": "friend_request", "friend_code": code])
        code = ""
    }

    private func saveProfile() {
        act("profile", ["action": "profile", "nickname": nickname.isEmpty ? model.profile.string("nickname") : nickname,
                        "collection_public": collectionPublic, "wishlist_public": wishlistPublic, "binder_public": binderPublic])
    }

    private func loadDraft() {
        guard !draftLoaded, !model.profile.isEmpty else { return }
        nickname = model.profile.string("nickname")
        collectionPublic = model.profile.bool("collection_public")
        wishlistPublic = model.profile.bool("wishlist_public")
        binderPublic = model.profile.bool("binder_public")
        // 토글의 onChange 가 불러오기를 저장으로 착각하지 않게 다음 틱에 연다.
        Task { @MainActor in draftLoaded = true }
    }

    private func friendAction(_ action: String, _ item: [String: Any]) {
        act("friends", ["action": action, "target_id": item.string("id"), "target_version": item.int("version")])
    }

    private func act(_ route: String, _ values: [String: Any]) { Task { await model.mutate(route, values) } }
}

/// 친구의 공개 바인더, 위시리스트, 컬렉션.
@MainActor
private struct FriendBinderSheet: View {
    @Bindable var model: OnlineHubModel
    @State private var preview: PrintingSelection?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let friend = model.documents["friend"] ?? [:]
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(friend.isEmpty ? "불러오는 중…" : "\(friend.string("nickname"))님의 카드").font(Typography.heading)
                Spacer()
                Button("닫기") {
                    model.selectedFriend = ""; model.documents["friend"] = nil; model.documents["friendInventory"] = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OnlineSection(title: "바인더") {
                        let keys = friend["binder"] as? [String] ?? []
                        if !friend.bool("binder_public") {
                            Text("바인더를 공개하지 않았어요.").font(Typography.label).foregroundStyle(.secondary)
                        } else if keys.isEmpty {
                            Text("바인더가 비어 있어요.").font(Typography.label).foregroundStyle(.secondary)
                        } else {
                            grid(keys.map { ($0, nil) })
                        }
                    }
                    if friend.bool("wishlist_public") {
                        OnlineSection(title: "갖고 싶어 하는 카드") {
                            let wishes = friend["wishlist"] as? [[String: Any]] ?? []
                            if wishes.isEmpty {
                                Text("적어 둔 카드가 없어요.").font(Typography.label).foregroundStyle(.secondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], alignment: .leading, spacing: 14) {
                                    ForEach(Array(wishes.enumerated()), id: \.offset) { _, wish in
                                        OnlineCardTile(cardID: wish.string("card_id"), finish: wish.string("finish"), width: 96) {
                                            Text("\(wish.int("missing"))장 더 필요").font(Typography.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if friend.bool("collection_public") {
                        OnlineSection(title: "컬렉션") {
                            let items = model.items("friendInventory")
                            if items.isEmpty {
                                Button("컬렉션 보기") { load(offset: 0) }
                            } else {
                                grid(items.map { ($0.string("printing"), "\($0.int("quantity"))장") })
                                if let next = model.documents["friendInventory"]?["next_offset"] as? Int {
                                    Button("더 보기") { load(offset: next) }.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 640, height: 600)
        .sheet(item: $preview) { OnlinePrintingDetail(printing: $0.id) }
    }

    private func grid(_ entries: [(key: String, note: String?)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], alignment: .leading, spacing: 14) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                let printing = CardPrintingKey(storageKey: entry.key)
                OnlineCardTile(cardID: printing.cardID, finish: printing.finish.rawValue, width: 96) {
                    if let note = entry.note { Text(note).font(Typography.caption).foregroundStyle(.secondary) }
                }
                .onTapGesture { preview = PrintingSelection(id: entry.key) }
            }
        }
    }

    private func load(offset: Int) {
        Task {
            do { model.documents["friendInventory"] = try await model.read("v1/inventory?target=\(model.selectedFriend)&offset=\(offset)") }
            catch { model.message = error.localizedDescription }
        }
    }
}

struct PrintingSelection: Identifiable { let id: String }

@MainActor
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

/// 카드 한 장을 크게. 판형과 참고 시세를 원화로 보여 준다.
@MainActor
struct OnlinePrintingDetail: View {
    let printing: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let key = CardPrintingKey(storageKey: printing)
        VStack(spacing: 12) {
            Text(OnlineText.cardName(key.cardID)).font(Typography.heading)
            Text("\(OnlineText.l.cardFinishName(key.finish)), \(CardIndex.shared?.card(key.cardID).flatMap { CardIndex.shared?.set($0.setID)?.name } ?? "")")
                .font(Typography.label).foregroundStyle(.secondary)
            OnlinePrintingArt(printing: printing, width: 260)
            if let won = OnlineText.referenceWon(printing), let prices = CardPrices.shared {
                Text("참고 시세 \(OnlineText.wonText(won))").font(Typography.bodySemibold).monospacedDigit()
                Text("\(prices.sourceDate(cardID: key.cardID, finish: key.finish)) 기준")
                    .font(Typography.caption).foregroundStyle(.secondary)
                if let source = prices.sourceURL(cardID: key.cardID, finish: key.finish), let url = URL(string: source), ["https", "http"].contains(url.scheme) {
                    Link("가격 출처 보기", destination: url).font(Typography.label)
                }
            }
            Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction).padding(.top, 4)
        }
        .padding(24)
    }
}
