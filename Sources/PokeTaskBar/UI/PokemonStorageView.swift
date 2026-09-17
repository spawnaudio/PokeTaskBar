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

    var body: some View {
        let l = store.l
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                sprite
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(l)).font(.callout.weight(.semibold))
                    Text(subtitle(l))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            if confirming {
                HStack(spacing: 8) {
                    Text(l.storageSwapConfirm)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(l.storageTrain) {
                        confirming = false
                        _ = store.swapFromStorage(item.id)
                    }
                    .tahoeButtonStyle(.prominent).controlSize(.small)
                    Button(l.cancel) { confirming = false }
                        .tahoeButtonStyle(.accessory).controlSize(.small)
                }
            } else {
                HStack {
                    Spacer()
                    Button(l.storageTrain) { confirming = true }
                        .tahoeButtonStyle(.regular).controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var sprite: some View {
        switch item {
        case .egg:
            SpriteView(speciesID: nil, size: 26)
                .frame(width: 30, height: 30)
        case .partner(_, let mon):
            SpriteView(speciesID: mon.currentID, size: 30, shiny: mon.isShiny)
        }
    }

    private func title(_ l: L) -> String {
        switch item {
        case .egg(_, let tier, _):
            return l.eggName(tier)
        case .partner:
            return l.storagePartner
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
