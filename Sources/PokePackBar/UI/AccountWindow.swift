import AppKit
import SwiftUI

@MainActor
final class AccountWindow: NSObject, NSWindowDelegate {
    static let shared = AccountWindow()
    private var window: NSWindow?

    func show(wallet: WalletStore, auditing: Bool = false) {
        OnlineText.wallet = wallet
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = OnlineText.l.accountWindowTitle
        window.minSize = NSSize(width: 560, height: 500)
        window.contentView = NSHostingView(rootView: OnlineSettingsView(wallet: wallet, auditSection: auditing ? .connection : nil).padding(24))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Destroy form state rather than retain passwords/recovery codes in a hidden view.
        window?.contentView = nil
        window = nil
    }
}
