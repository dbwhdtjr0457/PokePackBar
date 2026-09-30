import Foundation
import AppKit
import SwiftUI

/// Uses a new temporary wallet, never the player's save or inventory.
@MainActor
enum BulkOpeningAudit {
    static func benchmark(count: Int) async throws {
        guard let index = CardIndex.shared else { throw LocalAudit.Failure(description: "Missing index") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ppb-bulk-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game-state.json")
        var state = GameState()
        state.packs = ["zsv10pt5": count]
        try GamePersistence(url: url).commit(state)
        let wallet = WalletStore(fileURL: url)
        let seeds = (0..<count).map { UInt64(20260929 + $0) }
        let clock = ContinuousClock()
        var ticks = 0
        var worstGap = Duration.zero
        let heartbeat = Task { @MainActor in
            var previous = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                let now = clock.now
                worstGap = max(worstGap, previous.duration(to: now))
                previous = now
                ticks += 1
            }
        }
        defer { heartbeat.cancel() }
        await Task.yield()
        let start = clock.now
        guard let result = await wallet.openPacksAsync(setID: "zsv10pt5", count: count, index: index, seeds: seeds)
        else { throw LocalAudit.Failure(description: "Batch failed: \(wallet.persistenceError ?? "unknown")") }
        let elapsed = start.duration(to: clock.now)
        try await Task.sleep(for: .milliseconds(10))
        heartbeat.cancel()
        let restored = try GamePersistence(url: url).load().state
        try LocalAudit.require(result.packs.count == count && restored.packs["zsv10pt5"] == nil,
                               "Batch count or consumption mismatch")
        let presentationStart = clock.now
        let presentation = await Task.detached {
            PackPresentation(packs: result.packs, setID: "zsv10pt5", era: index.era("zsv10pt5"))
        }.value
        let presentationTime = presentationStart.duration(to: clock.now)
        try LocalAudit.require(presentation.imageIDs(at: 0).count <= PackPresentation.imageWindow,
                               "Unbounded initial image request")
        try LocalAudit.require(presentation.packCardCounts.reduce(0, +) == presentation.cards.count,
                               "Presentation lost pack boundaries")
        var owned = Set<String>()
        var pity = 0
        for (offset, opened) in result.packs.enumerated() {
            var generator = PackSeedGenerator(seed: seeds[offset])
            let reference = PackOpening.draw(setID: "zsv10pt5", index: index, alreadyOwned: owned,
                pity: &pity, mode: state.openingMode, using: &generator)
            try LocalAudit.require(reference == opened, "Draw/NEW/variant/order mismatch at \(offset)")
            owned.formUnion(reference.cards.filter { !$0.isSupplementalEnergy }.map(\.id))
        }
        try LocalAudit.require(restored.openingHistory.map(\.seed) == seeds.suffix(OpeningRules.historyLimit).map(String.init),
                               "History suffix changed")
        try LocalAudit.require((restored.packPity["zsv10pt5"] ?? 0) == pity, "Pity changed")
        try LocalAudit.require(ticks > 2, "Main actor never yielded during opening")
        print("BENCH bulk-opening packs=\(count) elapsed=\(elapsed) presentation=\(presentationTime) mainTicks=\(ticks) worstMainGap=\(worstGap) collected=\(restored.cards.values.reduce(0, +)) history=\(restored.openingHistory.count); seeded sequential parity; isolated wallet")
        try await auditTransactions(index: index, directory: directory)
        try await auditImages()
        if let at = CommandLine.arguments.firstIndex(of: "--render-bulk"),
           CommandLine.arguments.indices.contains(at + 1) {
            try await render(wallet: wallet, index: index, presentation: presentation,
                             output: URL(fileURLWithPath: CommandLine.arguments[at + 1]))
        }
    }

    private static func auditTransactions(index: CardIndex, directory: URL) async throws {
        let url = directory.appendingPathComponent("safety.json")
        var initial = GameState()
        initial.packs = ["sv8pt5": 10_000]
        try GamePersistence(url: url).commit(initial)
        let original = try Data(contentsOf: url)
        var commits = 0
        let failing = WalletStore(fileURL: url, dexes: [], ladder: [], commitState: { _ in
            commits += 1
            throw LocalAudit.Failure(description: "Injected commit failure")
        })
        let failed = await failing.openPacksAsync(setID: "sv8pt5", count: 1000, index: index)
        try LocalAudit.require(failed == nil && commits == 1 && failing.state.cards.isEmpty
            && failing.packCount(setID: "sv8pt5") == 10_000 && failing.unrevealed.isEmpty,
            "Failed batch did not roll back")
        try LocalAudit.require(try Data(contentsOf: url) == original, "Failed batch changed disk")

        let wallet = WalletStore(fileURL: url, dexes: [], ladder: [])
        let task = Task { await wallet.openPacksAsync(setID: "sv8pt5", count: 10_000, index: index) }
        while !wallet.isOpeningPacks { await Task.yield() }
        let duplicate = await wallet.openPacksAsync(setID: "sv8pt5", count: 1, index: index)
        try LocalAudit.require(duplicate == nil, "Concurrent batch accepted")
        task.cancel()
        let cancelled = await task.value
        try LocalAudit.require(cancelled == nil && !wallet.isOpeningPacks && wallet.state.cards.isEmpty,
                               "Cancelled preparation committed")
        try LocalAudit.require(try Data(contentsOf: url) == original, "Cancellation changed disk")

        let conflict = Task { await wallet.openPacksAsync(setID: "sv8pt5", count: 1000, index: index) }
        while !wallet.isOpeningPacks { await Task.yield() }
        wallet.setOpeningMode(.realistic)
        let rejected = await conflict.value
        try LocalAudit.require(rejected == nil && wallet.state.openingMode == .realistic
            && wallet.packCount(setID: "sv8pt5") == 10_000, "Stale batch overwrote live state")

        let merging = Task { await wallet.openPacksAsync(setID: "sv8pt5", count: 1000, index: index) }
        while !wallet.isOpeningPacks { await Task.yield() }
        wallet.addPack(setID: "sv8pt5")
        let merged = await merging.value
        try LocalAudit.require(merged?.packs.count == 1000 && wallet.packCount(setID: "sv8pt5") == 9001,
                               "Batch lost concurrently granted pack")
        print("PASS async opening: failed-save rollback, cancellation, duplicate prevention, stale-state rejection, concurrent grant preservation")
    }

    private static func auditImages() async throws {
        let ids = SupplementalEnergyCard.EnergyType.allCases.filter { $0 != .fairy }.map {
            "supplement-energy-mee30-\($0.rawValue)"
        }
        let images = await CardImageLoader.prefetch(cardIDs: Array(repeating: ids, count: 1000).flatMap { $0 }, hires: true)
        try LocalAudit.require(images.count == ids.count, "Duplicate-heavy prefetch dropped images")
        for id in ids {
            guard let image = images[id], let source = SupplementalEnergyCard.data(cardID: id),
                  let size = CardArtLibrary.dimensions(source) else {
                throw LocalAudit.Failure(description: "Missing English Energy decode")
            }
            try LocalAudit.require(image.size.width == CGFloat(size.width) && image.size.height == CGFloat(size.height),
                                   "Async decoder changed original resolution")
            try LocalAudit.require(CardImageLoader.preparedImage(cardID: id, hires: true) === image,
                                   "Decoded cache missed a repeated card")
        }
        print("PASS bounded prefetch: 8,000 duplicate requests -> 8 HD images, original dimensions, decoded memory cache")
    }

    private static func render(wallet: WalletStore, index: CardIndex, presentation: PackPresentation,
                               output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        wallet.setLanguage(.ko)
        for summary in [false, true] {
            let name = summary ? "summary" : "reveal"
            let view = PacksView.auditPresentation(wallet: wallet, index: index,
                                                   presentation: presentation, summary: summary)
                .frame(width: PopoverMetrics.contentWidth, height: PopoverMetrics.tabHeight)
                .padding(PopoverMetrics.padding)
                .background(Color(NSColor.windowBackgroundColor))
            let controller = NSHostingController(rootView: view)
            let size = NSSize(width: PopoverMetrics.width,
                              height: PopoverMetrics.tabHeight + 2 * PopoverMetrics.padding)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = controller
            controller.view.setFrameSize(size)
            let start = ContinuousClock.now
            controller.view.layoutSubtreeIfNeeded()
            let layoutDuration = start.duration(to: .now)
            try await Task.sleep(for: .milliseconds(700))
            controller.view.layoutSubtreeIfNeeded()
            controller.view.displayIfNeeded()
            guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds)
            else { throw LocalAudit.Failure(description: "Cannot render bulk \(name)") }
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:])
            else { throw LocalAudit.Failure(description: "Cannot encode bulk \(name)") }
            try data.write(to: output.appendingPathComponent("\(name).png"))
            print("RENDER bulk \(name): \(presentation.cards.count) cards; initial layout=\(layoutDuration)")
            window.close()
        }
    }
}
