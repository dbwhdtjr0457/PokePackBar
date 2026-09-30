import AppKit
import SwiftUI

@MainActor enum AccountLayoutAudit {
    static func run(output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let wallet = WalletStore(fileURL: output.appendingPathComponent("fixture.json"))
        let suite = "ppb-account-layout-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "disableKeychainAccess")
        let usage = UsageStore(providers: [], autoRefresh: false, defaults: defaults)
        let updater = UpdateChecker(currentVersion: "0.0.0")
        var measurements: [[String: Any]] = []
        func capture(_ name: String, view: AnyView, size: NSSize) async throws {
            let controller = NSHostingController(rootView: view.background(Color(NSColor.windowBackgroundColor)))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = controller
            controller.view.setFrameSize(size)
            controller.view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(200))
            controller.view.layoutSubtreeIfNeeded()
            guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
                throw LocalAudit.Failure(description: "Account layout capture failed")
            }
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw LocalAudit.Failure(description: "Account layout encoding failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            measurements.append(["screen": name, "width": size.width, "height": size.height,
                                 "minimumWidth": controller.view.fittingSize.width])
            window.close()
        }
        for section in ["일반", "표시", "데이터", "고급"] {
            try await capture("settings-\(section)", view: AnyView(SettingsView(onClose: {}, initialSection: section)
                .environment(usage).environment(wallet).environment(updater)),
                size: NSSize(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight))
        }
        for section in ["연결", "보안", "기기", "서버 상태"] {
            for width in [CGFloat(560), CGFloat(760)] {
                try await capture("account-\(section)-\(Int(width))", view: AnyView(OnlineSettingsView(wallet: wallet,
                    auditSection: section, signedIn: section != "연결").padding(24)
                    .preferredColorScheme(width == 760 ? .light : .dark)), size: NSSize(width: width, height: 560))
            }
        }
        try await capture("account-recover", view: AnyView(OnlineSettingsView(wallet: wallet, auditSection: "보안").padding(24)),
                          size: NSSize(width: 560, height: 500))
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("measurements.json"))
        for _ in 0..<2 {
            AccountWindow.shared.show(wallet: wallet, auditing: true)
            try await Task.sleep(for: .milliseconds(100))
            guard let window = NSApp.windows.first(where: { $0.title == "PPB 계정 및 서버" && $0.isVisible }) else {
                throw LocalAudit.Failure(description: "Account window did not reopen")
            }
            window.close()
            try LocalAudit.require(window.contentView == nil, "Hidden account form retained")
        }
        print("PASS account layout: 4 compact settings sections, 9 native states, light/dark, close/reopen and form disposal; isolated fixtures, no login")
    }
}
