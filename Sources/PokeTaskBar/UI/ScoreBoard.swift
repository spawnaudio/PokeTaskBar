import SwiftUI

/// Score + Coins. Shown on Focus and Today — work surfaces, not the Token usage page.
@MainActor
struct ScoreBoard: View {
    let store: CompanionStore

    private var l: L { store.l }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.scoreLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TokenFormatter.compact(store.lifetimeXP))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(l.scoreValue(TokenFormatter.compact(store.lifetimeXP)))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(l.coinsLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(TokenFormatter.compact(store.availableCoins))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
