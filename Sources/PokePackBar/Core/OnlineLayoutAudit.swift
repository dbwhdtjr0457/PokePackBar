import AppKit
import SwiftUI

/// Native production views, temporary fixtures only. Does not log in or poll.
@MainActor enum OnlineLayoutAudit {
    static func run(output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: output.appendingPathComponent("fixture.json"))
        wallet.setLanguage(LayoutAuditOptions.language)
        LayoutAuditOptions.applyAppearance()
        OnlineText.wallet = wallet
        let model = OnlineHubModel(wallet: wallet)
        let card = CardIndex.shared?.cards.first?.id ?? "base1-1"
        let profile: [String: Any] = ["nickname": "레이아웃 검사", "friend_code": "0123456789ABCDEF", "wishlist": [], "binder": []]
        let row: [String: Any] = ["id": UUID().uuidString, "printing": "\(card)#holo", "nickname": "교환 친구", "public_id": UUID().uuidString,
            "status": "pending", "incoming": true, "offered": ["\(card)#holo": 1], "requested": ["sv8pt5-1#normal": 2], "expires_at": Int(Date().timeIntervalSince1970) + 3600,
            "quantity": 4, "unit_tokens": 1200, "version": 0]
        // 알림은 최신순, 상대 이름과 카드가 붙은 것과 예전 서버처럼 붙지 않은 것을 함께 둔다.
        let now = Int(Date().timeIntervalSince1970)
        let notes: [[String: Any]] = [
            ["id": 4, "kind": "trade_request", "target": "t", "read": false, "created_at": now - 300,
             "detail": ["nickname": "교환 친구"]],
            ["id": 3, "kind": "listing_sold", "target": "l", "read": false, "created_at": now - 3 * 3600,
             "detail": ["printing": "\(card)#holo", "unit_tokens": 1_280_000]],
            ["id": 2, "kind": "friend_accept", "target": "f", "read": true, "created_at": now - 2 * 86_400,
             "detail": ["nickname": "새 친구"]],
            ["id": 1, "kind": "trade_expired", "target": "t", "read": true, "created_at": now - 9 * 86_400],
        ]
        // 친구 줄: 받은 신청, 친구, 보낸 신청. 친구 줄에는 교환 제안과 바인더 보기가 함께 놓인다.
        func friend(_ name: String, _ status: String, incoming: Bool) -> [String: Any] {
            ["id": UUID().uuidString, "version": 0, "status": status, "incoming": incoming, "public_id": UUID().uuidString,
             "nickname": name, "level": 12, "expires_at": now + 86_400]
        }
        let friends = [friend("새 친구", "pending", incoming: true), friend("교환 친구", "accepted", incoming: false),
                       friend("기다리는 친구", "pending", incoming: false)]
        model.documents = ["profile": ["profile": profile], "trades": ["items": [row]], "listings": ["items": [row.merging(["status": "active"]) { _, new in new }]],
                           "notifications": ["items": notes, "order": "desc"], "friends": ["items": friends]]
        model.data = ["totals": ["opened": 1200, "purchased": 1200, "new": 180, "duplicates": 11820], "collection_usd": 3141.59,
                      "variants": ["standard": 1199, "god": 1], "variant_rates": ["god": 1.0 / 1200]]
        model.openingJobs = [RemoteGameSession.OpeningJob(id: UUID().uuidString, set_id: "sv8pt5", total: 2500, completed: 1000,
            version: 1, status: "active", opening_mode: "realistic")]
        func capture(_ name: String, width: CGFloat) async throws {
            let size = NSSize(width: width, height: width == 740 ? 540 : 720)
            let host = NSHostingController(rootView: OnlineHubView(model: model).background(Color(NSColor.windowBackgroundColor)))
            host.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = host
            host.view.setFrameSize(size)
            host.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            host.view.layoutSubtreeIfNeeded()
            guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else { throw LocalAudit.Failure(description: "Online view capture failed") }
            host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw LocalAudit.Failure(description: "Online view encoding failed") }
            try png.write(to: output.appendingPathComponent("\(name)-\(Int(width)).png"))
            window.close()
        }
        for section in [OnlineHubModel.Tab.stats, .social, .trades, .market, .jobs, .alerts] {
            model.section = section
            for width in [CGFloat(740), CGFloat(980)] { try await capture(section.rawValue, width: width) }
        }
        // 알림을 눌러 들어왔을 때: 그 친구 줄과 판매 글에 테두리가 잘리지 않고 둘러져야 한다.
        model.follow(kind: "friend_accept", target: friends[1].string("id"))
        try await capture("social-from-alert", width: 980)
        model.follow(kind: "wishlist_listing", target: row.string("id"), printing: row.string("printing"))
        try await capture("market-from-alert", width: 980)
        model.focus(on: "")
        model.search = ""
        // 교환에 담을 카드를 고르는 창. 고르기 전에 카드마다 시세가 보여야 한다.
        let pickable = (CardIndex.shared?.currentCardsByValue.prefix(9) ?? []).enumerated().map { offset, entry in
            let key = "\(entry.id)#holo"
            return OnlineStock(key: key, cardID: entry.id, finish: .holo, available: offset + 1,
                               referenceWon: offset == 4 ? nil : OnlineText.referenceWon(key))
        }
        let picker = NSHostingController(rootView: OnlineStockPicker(
            wallet: wallet, title: OnlineText.l.addCardsToGive, actionTitle: OnlineText.l.addAction,
            source: pickable) { _, _ in }
            .background(Color(NSColor.windowBackgroundColor)))
        let pickerSize = picker.view.fittingSize
        let pickerWindow = NSWindow(contentRect: NSRect(origin: .zero, size: pickerSize), styleMask: [.borderless],
                                    backing: .buffered, defer: false)
        pickerWindow.isReleasedWhenClosed = false
        pickerWindow.contentViewController = picker
        picker.view.setFrameSize(pickerSize)
        picker.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        guard let pickerBitmap = picker.view.bitmapImageRepForCachingDisplay(in: picker.view.bounds) else {
            throw LocalAudit.Failure(description: "Stock picker capture failed")
        }
        picker.view.cacheDisplay(in: picker.view.bounds, to: pickerBitmap)
        guard let pickerPNG = pickerBitmap.representation(using: .png, properties: [:]) else {
            throw LocalAudit.Failure(description: "Stock picker encoding failed")
        }
        try pickerPNG.write(to: output.appendingPathComponent("trade-picker.png"))
        pickerWindow.close()

        model.documents = ["profile": ["profile": profile]]
        model.clearPrivateData()
        try LocalAudit.require(model.documents.isEmpty && model.data.isEmpty, "Logout retained online data")
        OnlineWindow.shared.show(wallet: wallet)
        NSApp.windows.first(where: { $0.title == OnlineText.l.onlineWindowTitle })?.close()
        OnlineWindow.shared.show(wallet: wallet)
        try LocalAudit.require(NSApp.windows.contains(where: { $0.title == OnlineText.l.onlineWindowTitle && $0.isVisible }), "Online window did not reopen")
        NSApp.windows.first(where: { $0.title == OnlineText.l.onlineWindowTitle })?.close()
        print("PASS online native layout: six sections at 740×540 and 980×720, arrivals from alerts, trade card picker, logout cache clearing, close/reopen")
    }
}
