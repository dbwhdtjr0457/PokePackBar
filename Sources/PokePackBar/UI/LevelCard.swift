import SwiftUI

/// 트레이너 레벨 한 칸. 통계 탭 맨 위에 둔다.
///
/// 레벨은 연 팩 수로 오르므로 따로 할 일이 없다. 이 칸은 **얼마나 왔고, 무엇을 받을 수
/// 있고, 다음에 무엇이 열리는지**를 한자리에 모은다. 받을 보상이 있으면 버튼이 앞에 나온다.
@MainActor
struct LevelCard: View {
    let wallet: WalletStore

    @State private var claiming = false
    @State private var notice: String?

    var body: some View {
        let l = wallet.l
        let level = wallet.level
        let opened = wallet.packsOpenedTotal
        let floor = LevelRules.packsRequired(for: level)
        let ceiling = LevelRules.packsRequired(for: level + 1)
        let atMax = level >= LevelRules.maxLevel
        let claimable = wallet.claimableLevels
        let rewards = claimable.map(LevelRules.reward(for:))
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l.levelShort(level)).font(Typography.amount).monospacedDigit()
                if let title = wallet.displayTitle(l) {
                    Text(title)
                        .font(Typography.labelSemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.accentColor, in: Capsule())
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(atMax ? l.levelMax : l.levelToNext(ceiling - opened))
                    .font(Typography.label).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            if !atMax {
                ProgressView(value: Double(opened - floor), total: Double(max(1, ceiling - floor)))
                    .progressViewStyle(.linear)
            }
            Text(l.levelOpened(opened)).font(Typography.label).foregroundStyle(.secondary)

            if !rewards.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill").foregroundStyle(.orange)
                    Text(l.levelRewardsReady(rewards.count, packs: rewards.reduce(0) { $0 + $1.packs }))
                        .font(Typography.bodySemibold)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button(l.levelClaim, action: claim)
                        .buttonStyle(.borderedProminent)
                        .font(Typography.button)
                        .disabled(claiming || wallet.resourceActionsDisabled)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            if let notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(Typography.label).foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let next = LevelRules.nextUnlock(after: level) {
                Label(l.levelNextUnlock(next), systemImage: "lock.open")
                    .font(Typography.label).foregroundStyle(.secondary)
            }
            Text(l.levelRewardRule)
                .font(Typography.caption).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func claim() {
        claiming = true
        Task {
            defer { claiming = false }
            guard let rewards = await wallet.claimLevelsOnlineAware(), !rewards.isEmpty else { return }
            SoundEffects.play(.chime(2))
            notice = wallet.l.levelClaimed(rewards.reduce(0) { $0 + $1.packs },
                                           coupons: rewards.reduce(0) { $0 + $1.couponCount })
        }
    }
}

/// 머리글의 레벨 표시. 받을 보상이 있으면 점이 붙고, 누르면 통계 탭의 레벨 칸으로 간다.
@MainActor
struct LevelChip: View {
    let wallet: WalletStore
    @Environment(PopoverNavigation.self) private var nav

    var body: some View {
        let ready = !wallet.claimableLevels.isEmpty
        Button { nav.tab = .stats } label: {
            HStack(spacing: 3) {
                Text(wallet.l.levelShort(wallet.level)).monospacedDigit()
                if ready {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                }
            }
            .font(Typography.labelSemibold)
            .foregroundStyle(ready ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(wallet.l.levelHeader)
    }
}
