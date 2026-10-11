import SwiftUI

/// Collection utilities; the Pokédex has its own dedicated root page.
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
                TahoeTabItem(.shop, title: l.shop, symbol: "cart"),
            ])

            Group {
                switch nav.collectionSegment {
                case .bag:
                    BagView(store: store, nav: navigation)
                case .storage:
                    PokemonStorageView(store: store)
                case .shop:
                    ShopView(store: store, nav: navigation)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
