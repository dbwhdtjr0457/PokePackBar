import AppKit
import SwiftUI

/// Native production views, temporary fixtures only. Does not log in or poll.
@MainActor enum OnlineLayoutAudit {
    static func run(output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: output.appendingPathComponent("fixture.json"))
        let model = OnlineHubModel(wallet: wallet)
        let card = CardIndex.shared?.cards.first?.id ?? "base1-1"
        let profile: [String: Any] = ["nickname": "레이아웃 검사", "friend_code": "0123456789ABCDEF", "wishlist": [], "binder": []]
        let row: [String: Any] = ["id": UUID().uuidString, "printing": "\(card)#holo", "nickname": "교환 친구", "public_id": UUID().uuidString,
            "status": "pending", "incoming": true, "offered": ["\(card)#holo": 1], "requested": ["sv8pt5-1#normal": 2], "expires_at": Int(Date().timeIntervalSince1970) + 3600,
            "quantity": 4, "unit_tokens": 1200, "version": 0]
        model.documents = ["profile": ["profile": profile], "trades": ["items": [row]], "listings": ["items": [row.merging(["status": "active"]) { _, new in new }]],
                           "notifications": ["items": [["id": 1, "kind": "trade_request", "target": "요청 식별자", "read": false]]]]
        model.data = ["totals": ["opened": 1200, "purchased": 1200, "new": 180, "duplicates": 11820], "collection_usd": 3141.59,
                      "variants": ["standard": 1199, "god": 1], "variant_rates": ["god": 1.0 / 1200]]
        model.openingJobs = [RemoteGameSession.OpeningJob(id: UUID().uuidString, set_id: "sv8pt5", total: 2500, completed: 1000,
            version: 1, status: "active", opening_mode: "realistic")]
        for section in ["통계", "컬렉션·친구", "교환", "마켓", "작업", "알림"] {
            model.section = section
            for width in [CGFloat(740), CGFloat(980)] {
                let size = NSSize(width: width, height: width == 740 ? 540 : 720)
                let host = NSHostingController(rootView: OnlineHubView(model: model).background(Color(NSColor.windowBackgroundColor)))
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
                try png.write(to: output.appendingPathComponent("\(section)-\(Int(width)).png"))
                window.close()
            }
        }
        model.documents = ["profile": ["profile": profile]]
        model.clearPrivateData()
        try LocalAudit.require(model.documents.isEmpty && model.data.isEmpty, "Logout retained online data")
        OnlineWindow.shared.show(wallet: wallet)
        NSApp.windows.first(where: { $0.title == "PPB 온라인" })?.close()
        OnlineWindow.shared.show(wallet: wallet)
        try LocalAudit.require(NSApp.windows.contains(where: { $0.title == "PPB 온라인" && $0.isVisible }), "Online window did not reopen")
        NSApp.windows.first(where: { $0.title == "PPB 온라인" })?.close()
        print("PASS online native layout: six sections at 740×540 and 980×720, logout cache clearing, close/reopen")
    }
}
