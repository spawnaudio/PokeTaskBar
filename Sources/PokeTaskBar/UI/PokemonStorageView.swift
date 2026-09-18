import SwiftUI

/// Pokémon Storage — eggs and mid-evolution partners. One trainee at a time; swap anytime.
@MainActor
struct PokemonStorageView: View {
    let store: CompanionStore

    private var l: L { store.l }

    var body: some View {
        if store.storedCompanions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.pokemonStorageHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(store.storedCompanions) { item in
                        StorageRow(store: store, item: item)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            SpriteView(speciesID: 132, size: 72, animated: true)
            Text(l.pokemonStorageEmpty)
                .font(.callout.weight(.semibold))
            Text(l.pokemonStorageHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

@MainActor
struct StorageRow: View {
    let store: CompanionStore
    let item: PokemonStorageItem
    @State private var confirming = false
    /// Fills the card’s content height (name + subtitle). Eggs and partners share it.
    static let thumbSlot: CGFloat = 48
    /// Drawn size matches the slot so the sprite is not a padded thumbnail.
    static let thumbSprite: CGFloat = 48

    var body: some View {
        let l = store.l
        HStack(alignment: .top, spacing: 10) {
            sprite
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    title
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 8)
                    trainActions(l)
                }
                Text(subtitle(l))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if confirming {
                    Text(l.storageSwapConfirm)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: item.id) {
            if case .partner(_, let mon) = item {
                await store.ensureStoredPartnerLine(mon)
            }
        }
    }

    @ViewBuilder
    private func trainActions(_ l: L) -> some View {
        if confirming {
            HStack(spacing: 6) {
                Button(l.storageTrain) {
                    confirming = false
                    _ = store.swapFromStorage(item.id)
                }
                .tahoeButtonStyle(.prominent).controlSize(.small)
                Button(l.cancel) { confirming = false }
                    .tahoeButtonStyle(.accessory).controlSize(.small)
            }
            .fixedSize()
        } else {
            Button(l.storageTrain) { confirming = true }
                .tahoeButtonStyle(.regular).controlSize(.small)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var sprite: some View {
        switch item {
        case .egg:
            SpriteView(speciesID: nil, size: Self.thumbSprite, cropToContent: true)
                .frame(width: Self.thumbSlot, height: Self.thumbSlot)
        case .partner(_, let mon):
            SpriteView(speciesID: mon.currentID, size: Self.thumbSprite, shiny: mon.isShiny,
                       cropToContent: true)
                .frame(width: Self.thumbSlot, height: Self.thumbSlot)
        }
    }

    @ViewBuilder
    private var title: some View {
        switch item {
        case .egg(_, let tier, _):
            Text(store.l.eggName(tier))
        case .partner(_, let mon):
            Text(store.displayName(for: mon))
        }
    }

    private func subtitle(_ l: L) -> String {
        switch item {
        case .egg(_, let tier, _):
            return tier.map { l.eggGuaranteeHint($0) } ?? l.pokemonStorageEggHint
        case .partner(_, let mon):
            return l.storagePartnerHint(stage: mon.stageIndex + 1, total: mon.totalForms)
        }
    }
}
