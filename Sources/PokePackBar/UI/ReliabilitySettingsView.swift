import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ReliabilitySettingsView: View {
    let wallet: WalletStore
    @State private var message: String?
    private var l: L { wallet.l }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.openingSettings).font(Typography.bodySemibold)
            Picker(l.openingSettings, selection: Binding(get: { wallet.state.openingMode },
                                                        set: { wallet.setOpeningMode($0) })) {
                ForEach(OpeningMode.allCases, id: \.self) { mode in
                    Text(l.openingMode(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(l.realisticNote).font(Typography.label).foregroundStyle(.secondary)
            DisclosureGroup("\(l.exportHistory) (\(wallet.state.openingHistory.count))") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l.historyNote).font(Typography.label).foregroundStyle(.secondary)
                    ForEach(wallet.state.openingHistory.suffix(10).reversed()) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.setID) · \(record.openedAt.formatted(date: .abbreviated, time: .shortened))")
                            Text(record.printings.map { "\($0.cardID) [\(l.cardFinishName($0.finish))]" }.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                            if record.supplement.energyCount > 0 {
                                Text(l.supplement(record.supplement))
                            }
                        }.font(Typography.label)
                    }
                    Button(l.exportHistory, action: exportHistory)
                        .disabled(wallet.state.openingHistory.isEmpty)
                }.padding(.top, 6)
            }
            Button(l.backups) { NSWorkspace.shared.open(wallet.saveBackupDirectory) }
            Divider()
            Text(l.priceData).font(Typography.bodySemibold)
            if let prices = CardPrices.shared {
                Text("\(prices.printingCount.formatted()) · \(l.exactPrintingPrice) · \(l.latestQuoteDate) \(prices.printingAsOf ?? prices.asOf)")
                    .help(l.mixedPriceSource)
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            HStack {
                Button(l.importPrices, action: importPrices)
                Button(l.resetPrices) {
                    do { try PriceSnapshotStore.shared.reset(); message = l.pricesApplied }
                    catch { message = error.localizedDescription }
                }.disabled(!PriceSnapshotStore.shared.usesImportedSnapshot)
            }
            if let message { Text(message).font(Typography.label).textSelection(.enabled) }
        }
    }

    private func importPrices() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PriceSnapshotStore.read(url)
            let snapshot = try PriceSnapshotStore.validate(data)
            let alert = NSAlert()
            alert.messageText = l.confirmPriceImport
            alert.informativeText = "\(snapshot.cards.asOf) / \(snapshot.cards.printingAsOf ?? snapshot.cards.asOf) · \(snapshot.cards.printingCount)"
            alert.addButton(withTitle: l.importPrices)
            alert.addButton(withTitle: l.cancel)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            try PriceSnapshotStore.shared.apply(data)
            message = l.pricesApplied
        } catch { message = error.localizedDescription }
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "pokepackbar-opening-history.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Foundation reference-date encoding is shared by replay and save decoding.
            try encoder.encode(wallet.state.openingHistory).write(to: url, options: .atomic)
        } catch { message = error.localizedDescription }
    }
}
