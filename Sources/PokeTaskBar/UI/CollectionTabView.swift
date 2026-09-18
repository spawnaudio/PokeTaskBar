import SwiftUI

/// Collection root: Bag | Dex | Shop. Dex is the default segment.
@MainActor
struct CollectionTabView: View {
    let store: CompanionStore
    let navigation: PopoverNavigation

    private var l: L { store.l }

    var body: some View {
        @Bindable var nav = navigation
        VStack(alignment: .leading, spacing: 8) {
            TahoeTabBar(selection: $nav.collectionSegment, items: [
                TahoeTabItem(.bag, title: l.bag, symbol: "bag"),
                TahoeTabItem(.storage, title: l.pokemonStorage, symbol: "archivebox"),
                TahoeTabItem(.dex, title: l.dexSegment, symbol: "square.grid.2x2"),
                TahoeTabItem(.shop, title: l.shop, symbol: "cart"),
            ])

            Group {
                switch nav.collectionSegment {
                case .bag:
                    BagView(store: store, nav: navigation)
                case .storage:
                    PokemonStorageView(store: store)
                case .dex:
                    CollectionView(store: store, navigation: navigation)
                case .shop:
                    ShopView(store: store, nav: navigation)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
