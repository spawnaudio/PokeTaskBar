import SwiftUI

@MainActor
struct MainWindowCollectionView: View {
    @Environment(CompanionStore.self) private var store
    @Environment(MainWindowNavigation.self) private var nav
    @Environment(\.colorScheme) private var scheme
    @State private var filter: DexHeaderFilter?
    @State private var query = ""
    @State private var detailSpecies: CompanionStore.DexSpecies?
    @State private var detailInstanceID: String?
    private var l: L { store.l }

    var body: some View {
        @Bindable var content = nav.content
        VStack(alignment: .leading, spacing: 20) {
            TahoeTabBar(selection: $content.collectionSegment, items: [
                TahoeTabItem(.bag, title: l.bag, symbol: "bag"),
                TahoeTabItem(.storage, title: l.pokemonStorage, symbol: "archivebox"),
                TahoeTabItem(.dex, title: l.dexSegment, symbol: "square.grid.2x2"),
                TahoeTabItem(.shop, title: l.shop, symbol: "cart")])
            if let species = detailSpecies {
                PokemonDetailView(store: store, species: species, initialInstanceID: detailInstanceID) {
                    detailSpecies = nil; detailInstanceID = nil
                }
            } else {
                switch content.collectionSegment {
                case .bag: bag
                case .storage: storage
                case .dex: dex
                case .shop: shop
                }
            }
        }
        .onChange(of: content.collectionSegment) { _, _ in detailSpecies = nil; detailInstanceID = nil }
        .task { await store.backfillMissingDexNames() }
    }

    private var bag: some View {
        MainWindowSplit {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items").font(.system(size: 18, weight: .semibold))
                    ForEach(store.ownedItems, id: \.kind) { item in
                        Button { nav.selectedItem = item.kind } label: {
                            HStack(spacing: 12) {
                                ItemIconView(kind: item.kind, size: 38)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(l.itemName(item.kind)).fontWeight(.medium)
                                    Text(item.kind.isPassive ? l.ownedAlready : "× \(item.count)")
                                        .font(.system(size: 12)).foregroundStyle(.secondary)
                                }; Spacer()
                            }.padding(12).contentShape(Rectangle())
                                .background(selectedItem == item.kind ? MainWindowTheme(scheme: scheme).selected : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                    if store.ownedItems.isEmpty { Text(l.bagEmptyTitle).foregroundStyle(.secondary) }
                    if !store.storedCompanions.filter(\.isEgg).isEmpty {
                        Text("Stored eggs").foregroundStyle(.secondary).padding(.top, 20)
                        ForEach(store.storedCompanions.filter(\.isEgg)) { item in
                            StorageRow(store: store, item: item)
                        }
                    }
                    Button("Manage in Storage →") { nav.content.collectionSegment = .storage }
                        .buttonStyle(.link).padding(.top, 10)
                }
            }.mainWindowCard()
        } detail: {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Current Pokémon").font(.system(size: 12)).foregroundStyle(.secondary)
                    MainWindowCompanionHero(size: 230)
                    if let kind = selectedItem {
                        ItemCard(store: store, nav: nav.content, kind: kind, count: store.itemCount(kind)).id(kind)
                    }
                }.frame(maxWidth: .infinity)
            }.mainWindowCard()
        }
    }
    private var selectedItem: ItemKind? {
        store.ownedItems.contains(where: { $0.kind == nav.selectedItem }) ? nav.selectedItem : store.ownedItems.first?.kind
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SpriteView(speciesID: store.currentSpeciesID, size: 42, shiny: store.currentIsShiny, cropToContent: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currently training").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(store.state.trainingEmpty ? "No current Pokémon" : store.displayName).fontWeight(.medium)
                }
                Spacer()
            }.padding(12)
            if store.storedCompanions.isEmpty { PokemonStorageView(store: store) }
            else {
                MainWindowSplit {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.storedCompanions) { item in
                                selectionRow(name: storageName(item), subtitle: storageSubtitle(item),
                                    id: storageSpecies(item), shiny: storageShiny(item), selected: selectedStorage?.id == item.id) {
                                    nav.selectedStorageID = item.id
                                }
                                .task(id: item.id) {
                                    if case .partner(_, let mon) = item { await store.ensureStoredPartnerLine(mon) }
                                }
                            }
                        }
                    }.mainWindowCard()
                } detail: {
                    if let item = selectedStorage {
                        ScrollView {
                            VStack(spacing: 28) {
                                Text(storageName(item)).font(.system(size: 26, weight: .semibold))
                                SpriteView(speciesID: storageSpecies(item), size: 220, animated: true,
                                           shiny: storageShiny(item), cropToContent: true)
                                StorageRow(store: store, item: item).id(item.id)
                            }.frame(maxWidth: .infinity)
                        }.mainWindowCard()
                    }
                }
            }
        }
    }
    private var selectedStorage: PokemonStorageItem? {
        store.storedCompanions.first { $0.id == nav.selectedStorageID } ?? store.storedCompanions.first
    }
    private func storageName(_ item: PokemonStorageItem) -> String {
        switch item { case .egg(_, let tier, _): l.eggName(tier); case .partner(_, let mon): store.displayName(for: mon) }
    }
    private func storageSubtitle(_ item: PokemonStorageItem) -> String {
        switch item {
        case .egg(_, let tier, _): tier.map { l.eggGuaranteeHint($0) } ?? l.pokemonStorageEggHint
        case .partner(_, let mon): l.storagePartnerHint(stage: mon.stageIndex + 1, total: mon.totalForms)
        }
    }
    private func storageSpecies(_ item: PokemonStorageItem) -> Int? {
        if case .partner(_, let mon) = item { return mon.currentID }; return nil
    }
    private func storageShiny(_ item: PokemonStorageItem) -> Bool {
        if case .partner(_, let mon) = item { return mon.isShiny }; return false
    }

    private var species: [CompanionStore.DexSpecies] {
        store.dexSpecies.filter { matches(rarity: $0.rarity, shiny: $0.isShiny) &&
            (query.isEmpty || "\($0.name) \($0.id)".localizedCaseInsensitiveContains(query)) }
    }
    private var records: [DexEntry] {
        store.dexEntriesSorted.filter { matches(rarity: $0.rarity, shiny: $0.isShiny) &&
            (query.isEmpty || recordName($0).localizedCaseInsensitiveContains(query)) }
    }
    private func matches(rarity: Rarity, shiny: Bool) -> Bool {
        switch filter { case .none: true; case .rarity(let value): rarity == value; case .shiny: shiny }
    }
    private var dex: some View {
        @Bindable var content = nav.content
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Collection records", selection: $content.showingCollectionLog) {
                    Text(l.dexSegment).tag(false); Text("Catch log").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                Spacer()
                Text("\(content.showingCollectionLog ? store.dexEntries.count : store.dexSpecies.count) \(content.showingCollectionLog ? "catches" : "species")")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            TextField("Find a Pokémon…", text: $query).textFieldStyle(.roundedBorder)
            DexFilterBar(localization: l, selected: filter,
                rarityCounts: Dictionary(uniqueKeysWithValues: rarityDisplayOrder.map { rarity in
                    (rarity, content.showingCollectionLog ? store.dexCount(rarity) : store.dexSpecies.filter { $0.rarity == rarity }.count)
                }), shinyCount: content.showingCollectionLog ? store.dexShinyCount : store.dexSpecies.filter(\.isShiny).count) {
                    filter = filter == $0 ? nil : $0
                }
            if content.showingCollectionLog { catchLog } else { pokedex }
        }
    }
    private var pokedex: some View {
        MainWindowSplit {
            ScrollView {
                LazyVStack(spacing: 6) {
                    if species.isEmpty { Text("No matching Pokémon.").foregroundStyle(.secondary).padding() }
                    ForEach(species) { pokemon in
                        selectionRow(name: pokemon.name, subtitle: String(format: "#%03d", pokemon.id), id: pokemon.id,
                            shiny: pokemon.isShiny, selected: selectedSpecies?.id == pokemon.id) { nav.selectedSpeciesID = pokemon.id }
                    }
                }
            }.mainWindowCard()
        } detail: {
            if let pokemon = selectedSpecies {
                ScrollView {
                    VStack(spacing: 20) {
                        Text(pokemon.name).font(.system(size: 28, weight: .semibold))
                        Text("#\(pokemon.id) · \(l.rarityLabel(pokemon.rarity))\(pokemon.isRaising ? " · " + l.dexRaising : "")")
                            .foregroundStyle(.secondary)
                        SpriteView(speciesID: pokemon.id, size: 220, animated: true, shiny: pokemon.isShiny, cropToContent: true)
                        Button(store.representativeSpeciesID == pokemon.id ? "Representative Pokémon" : "Set representative") {
                            _ = store.setRepresentativeSpeciesID(pokemon.id)
                        }.tahoeButtonStyle(.regular).disabled(store.representativeSpeciesID == pokemon.id)
                        Text("\(store.pokemonIndividuals(speciesID: pokemon.id).count) collected individuals")
                            .foregroundStyle(.secondary)
                        Button("View details →") { detailSpecies = pokemon; detailInstanceID = nil }.buttonStyle(.link)
                    }.frame(maxWidth: .infinity)
                }.mainWindowCard()
            }
        }
    }
    private var selectedSpecies: CompanionStore.DexSpecies? { species.first { $0.id == nav.selectedSpeciesID } ?? species.first }
    private var selectedRecord: DexEntry? { records.first { $0.id == nav.selectedRecordID } ?? records.first }
    private func recordName(_ entry: DexEntry) -> String { store.dexStoredChainNames(entry)?[entry.finalID] ?? "#\(entry.finalID)" }
    private func recordState(_ entry: DexEntry) -> String {
        store.isActiveDexEntry(entry) ? l.dexRaising : entry.isReleased ? l.dexReleased : l.dexTrophy
    }
    private var catchLog: some View {
        MainWindowSplit {
            ScrollView {
                LazyVStack(spacing: 6) {
                    if records.isEmpty { Text("No matching records.").foregroundStyle(.secondary).padding() }
                    ForEach(records) { entry in
                        selectionRow(name: recordName(entry),
                            subtitle: "\(recordState(entry)) · \(entry.caughtAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")",
                            id: entry.finalID, shiny: entry.isShiny, selected: selectedRecord?.id == entry.id) {
                                nav.selectedRecordID = entry.id
                            }
                    }
                }
            }.mainWindowCard()
        } detail: {
            if let entry = selectedRecord {
                ScrollView {
                    VStack(spacing: 20) {
                        Text(recordName(entry)).font(.system(size: 28, weight: .semibold))
                        Text("\(l.rarityLabel(entry.rarity)) · \(recordState(entry))\(entry.isShiny ? " · " + l.dexShinyLabel : "")")
                            .foregroundStyle(.secondary)
                        SpriteView(speciesID: entry.finalID, size: 200, animated: true, shiny: entry.isShiny, cropToContent: true)
                        Text(entry.nature?.name(store.language) ?? "Unknown nature")
                        Text(entry.caughtAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date").foregroundStyle(.secondary)
                        EvoLineView(nodes: entry.chainOrder.map { EvoLineItem(.species($0), .done) },
                            mysteryLabel: l.unknownNextEvolution, language: store.language, thumb: 40,
                            shiny: entry.isShiny, names: store.dexStoredChainNames(entry), maxWidth: 360)
                        Button("View details →") {
                            detailInstanceID = entry.id
                            detailSpecies = store.dexSpecies.first { $0.id == entry.finalID }
                        }.buttonStyle(.link)
                    }.frame(maxWidth: .infinity)
                }.mainWindowCard()
            }
        }
    }
    private func selectionRow(name: String, subtitle: String, id: Int?, shiny: Bool, selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SpriteView(speciesID: id, size: 38, shiny: shiny, cropToContent: true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).fontWeight(.medium)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(10).contentShape(Rectangle())
                .background(selected ? MainWindowTheme(scheme: scheme).selected : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    private var shop: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l.shop).font(.system(size: 24, weight: .semibold))
                        Text("Items for your next session.").foregroundStyle(.secondary)
                    }; Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(TokenFormatter.grouped(store.availableCoins)) Coins").font(.system(size: 22, weight: .semibold))
                        Text(l.spendableCoins).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(store.shopEntries, id: \.self) { entry in
                        Group {
                            switch entry {
                            case .item(let kind): ShopItemCard(store: store, kind: kind)
                            case .egg(let tier): EggCard(store: store, nav: nav.content, tier: tier)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading).mainWindowCard()
                    }
                }
                Text("Eggs go to Storage. Your current Pokémon keeps training.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    Button("Open Bag →") { nav.content.collectionSegment = .bag }
                    Button("Open Storage →") { nav.content.collectionSegment = .storage }
                }.buttonStyle(.link)
            }
        }.scrollIndicators(.hidden)
    }
}

@MainActor
struct MainWindowSplit<Browser: View, Detail: View>: View {
    @ViewBuilder let browser: () -> Browser
    @ViewBuilder let detail: () -> Detail
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 580 {
                HStack(alignment: .top, spacing: 16) {
                    browser().frame(width: min(300, geometry.size.width * 0.37))
                    detail().frame(maxWidth: .infinity)
                }.frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    browser().frame(height: min(210, geometry.size.height * 0.35))
                    detail().frame(maxHeight: .infinity)
                }
            }
        }
    }
}
