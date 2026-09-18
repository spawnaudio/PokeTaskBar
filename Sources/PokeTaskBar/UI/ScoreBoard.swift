import SwiftUI

/// Score + Coins. Shown on Focus and Today — work surfaces, not the Token usage page.
@MainActor
struct ScoreBoard: View {
    let store: CompanionStore
    var compact: Bool = false

    private var l: L { store.l }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            let layout = compact ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            layout {
                Text(l.scoreLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TokenFormatter.compact(store.lifetimeXP))
                    .font(.system(size: compact ? 12 : 24, weight: compact ? .medium : .bold,
                                  design: compact ? .default : .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(l.scoreValue(TokenFormatter.compact(store.lifetimeXP)))
            }
            Spacer(minLength: 8)
            let trailingLayout = compact ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(alignment: .trailing, spacing: 2))
            trailingLayout {
                Text(l.coinsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TokenFormatter.compact(store.availableCoins))
                    .font(.system(size: compact ? 12 : 24, weight: compact ? .medium : .bold,
                                  design: compact ? .default : .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(l.coinsValue(TokenFormatter.compact(store.availableCoins)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if store.mintIsActive {
                Text(l.mintActiveHint(minutes: Int(ceil(store.mintRemaining / 60))))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: 18)
            }
        }
        .padding(.bottom, store.mintIsActive ? 16 : 0)
    }
}
