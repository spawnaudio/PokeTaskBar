import SwiftUI

/// A dedicated Pokédex, shared by the menu-bar and desktop windows. Only the
/// selected registered entry loads metadata; unknown rows never fetch sprites.
@MainActor
struct PokedexPageView: View {
    let store: CompanionStore
    var spacious = false
    private let catchLogSelection: Binding<Bool>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var localCatchLog: Bool
    @State private var variant: PokedexVariant = .normal
    @State private var region: PokedexRegion = .national
    @State private var registrationFilter: RegistrationFilter = .all
    @State private var query = ""
    @State private var selectedID = 1
    @State private var selectedInstanceID: String?
    @State private var showingDetails = false

    init(store: CompanionStore, spacious: Bool = false, initialShowingCatchLog: Bool = false,
         showingCollectionLog: Binding<Bool>? = nil) {
        self.store = store
        self.spacious = spacious
        self.catchLogSelection = showingCollectionLog
        _localCatchLog = State(initialValue: initialShowingCatchLog)
    }

    private enum RegistrationFilter: String, CaseIterable, Identifiable {
        case all, registered, unregistered
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private var l: L { store.l }
    private var showingCatchLog: Bool { catchLogSelection?.wrappedValue ?? localCatchLog }
    private var catchLogBinding: Binding<Bool> {
        Binding(get: { showingCatchLog }, set: { value in
            if let catchLogSelection { catchLogSelection.wrappedValue = value }
            else { localCatchLog = value }
            showingDetails = false
        })
    }
    private var registration: PokedexRegistration {
        let stored = store.storedCompanions.compactMap { item -> MonState? in
            if case .partner(_, let mon) = item { return mon }
            return nil
        }
        return PokedexRegistration(records: store.state.dex,
                                   partners: stored + [store.state.active].compactMap { $0 })
    }
    private var speciesByID: [Int: CompanionStore.DexSpecies] {
        Dictionary(uniqueKeysWithValues: store.dexSpecies.map { ($0.id, $0) })
    }
    private var registeredIDs: Set<Int> { registration.speciesIDs(for: variant) }
    private var registeredCount: Int { registeredIDs.filter(region.speciesIDs.contains).count }
    private var registryIDs: [Int] {
        let names = speciesByID
        let known = registeredIDs
        return region.speciesIDs.filter { id in
            let registered = known.contains(id)
            if registrationFilter == .registered && !registered { return false }
            if registrationFilter == .unregistered && registered { return false }
            return matchesQuery(id: id, name: registered ? names[id]?.name : nil)
        }
    }
    private var records: [DexEntry] {
        store.pokemonCatchLogEntries.filter { entry in
            entry.isShiny == (variant == .shiny) && region.speciesIDs.contains(entry.finalID)
                && matchesQuery(id: entry.finalID, name: recordName(entry))
        }
    }
    private var browserIDs: [Int] { showingCatchLog ? records.map(\.finalID) : registryIDs }
    private var selectedSpecies: CompanionStore.DexSpecies? {
        guard registration.contains(selectedID, variant: variant), let species = speciesByID[selectedID] else { return nil }
        return CompanionStore.DexSpecies(id: species.id, name: species.name, rarity: species.rarity,
                                         isShiny: variant == .shiny,
                                         isRaising: species.isRaising && store.currentIsShiny == (variant == .shiny),
                                         unownForm: species.unownForm)
    }
    private var individuals: [DexEntry] {
        let entries: [DexEntry]
        if selectedID == UnownForm.speciesID {
            entries = store.unownFormSpecies.flatMap {
                store.pokemonIndividuals(speciesID: selectedID, unownForm: $0.unownForm)
            }
        } else { entries = store.pokemonIndividuals(speciesID: selectedID) }
        return entries.filter { $0.isShiny == (variant == .shiny) }
    }
    private var selectedIndividual: DexEntry? {
        individuals.first { $0.id == selectedInstanceID } ?? individuals.first
    }

    var body: some View {
        ContentFittingScrollView(fillsViewport: true) {
            VStack(spacing: 16) {
                deviceHeader
                if showingDetails, let species = selectedSpecies {
                    PokemonDetailView(store: store, species: species,
                                      initialInstanceID: selectedIndividual?.id) { showingDetails = false }
                        .id("\(species.id)-\(selectedIndividual?.id ?? "species")")
                        .padding(12)
                        .frame(height: spacious ? 640 : 490)
                        .background(PokedexPalette.detail, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(PokedexPalette.ink)
                        .environment(\.colorScheme, .light)
                } else {
                    pageMode
                    if spacious {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                scanner.frame(minWidth: 270, maxWidth: .infinity)
                                hinge
                                registry.frame(minWidth: 280, maxWidth: .infinity)
                            }
                            VStack(spacing: 16) { scanner; registry }
                        }
                    } else {
                        VStack(spacing: 14) { scanner; registry }
                    }
                    deviceFooter
                }
            }
            .padding(spacious ? 22 : 14)
            .frame(maxWidth: 1000, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [PokedexPalette.red, PokedexPalette.deepRed],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(PokedexPalette.rim, lineWidth: 2)
                    }
            }
            .foregroundStyle(.white)
            .padding(.bottom, 8)
        }
        .task {
            if let id = store.currentSpeciesID, PokemonAssets.hasAnimatedSprite(speciesID: id) {
                selectedID = id
                variant = store.currentIsShiny ? .shiny : .normal
            } else if let id = registeredIDs.min() { selectedID = id }
            await store.backfillMissingDexNames()
            for item in store.storedCompanions {
                if case .partner(_, let mon) = item { await store.ensureStoredPartnerLine(mon) }
            }
        }
        .task(id: "\(selectedID)-\(variant.rawValue)") {
            guard selectedSpecies != nil else { return }
            await store.loadPokemonDetails(speciesID: selectedID)
        }
        .onChange(of: browserIDs) { _, ids in
            guard !ids.contains(selectedID), let first = ids.first else { return }
            selectSpecies(first)
        }
        .onChange(of: variant) { _, _ in selectedInstanceID = nil; showingDetails = false }
    }

    private var deviceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle().fill(PokedexPalette.sensor)
                .overlay(alignment: .topLeading) {
                    Circle().fill(.white.opacity(0.8)).frame(width: 11, height: 11).padding(8)
                }
                .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 4) }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    indicator(PokedexPalette.lampRed)
                    indicator(PokedexPalette.lampYellow)
                    indicator(PokedexPalette.lampGreen)
                }.accessibilityHidden(true)
                Text("POKÉDEX")
                    .font(.system(size: spacious ? 23 : 19, weight: .heavy, design: .rounded))
                    .tracking(2)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text("GEN I — V").font(.system(size: 9, weight: .semibold, design: .monospaced))
                Text("#001–649").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(PokedexPalette.rim).frame(height: 2) }
    }

    private var pageMode: some View {
        Picker("Pokédex view", selection: catchLogBinding) {
            Text("Registry").tag(false)
            Text("Catch log").tag(true)
        }
        .pickerStyle(.segmented)
        .colorScheme(.light)
        .accessibilityLabel("Pokédex view")
    }

    private var scanner: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                HStack {
                    Circle().fill(selectedSpecies == nil ? PokedexPalette.ink.opacity(0.25) : PokedexPalette.ink)
                        .frame(width: 6, height: 6).accessibilityHidden(true)
                    Text(selectedSpecies == nil ? "NO DATA" : "REGISTERED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                    Spacer()
                    Text(String(format: "No. %03d", selectedID))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                ZStack {
                    PokedexScanGrid().stroke(PokedexPalette.ink.opacity(0.07), lineWidth: 1)
                    if let species = selectedSpecies {
                        SpriteView(speciesID: selectedID, size: spacious ? 154 : 116,
                                   animated: !reduceMotion, shiny: variant == .shiny,
                                   minFrameDelay: 0.1, cropToContent: true,
                                   unownForm: selectedIndividual?.unownForm ?? species.unownForm)
                            .accessibilityLabel("\(species.name)\(variant == .shiny ? ", " + l.dexShinyLabel : "")")
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark").font(.system(size: 44, weight: .light))
                            Text("AWAITING DISCOVERY").font(.system(size: 8, weight: .medium, design: .monospaced))
                        }.foregroundStyle(PokedexPalette.ink.opacity(0.5))
                    }
                }
                .frame(height: spacious ? 164 : 126)
                Text(selectedSpecies?.name ?? "Unregistered")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .lineLimit(2).multilineTextAlignment(.center)
                scanData
            }
            .padding(14)
            .foregroundStyle(PokedexPalette.ink)
            .background(PokedexPalette.lcd, in: RoundedRectangle(cornerRadius: 6))
            .padding(10)
            .background(PokedexPalette.bezel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    Circle().fill(PokedexPalette.lampRed).frame(width: 5, height: 5)
                    ForEach(0..<4) { _ in Capsule().fill(PokedexPalette.ink.opacity(0.5)).frame(width: 18, height: 2) }
                }.offset(y: -3).accessibilityHidden(true)
            }
            scanControls
            if let entry = selectedIndividual { individualReadout(entry) }
            else if selectedSpecies != nil {
                Text("Species reference · This individual has evolved to another form.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var scanData: some View {
        if selectedSpecies == nil {
            Text(variant == .shiny ? "Discover a shiny Pokémon to record this variant."
                                  : "Catch or evolve a Pokémon to register its data.")
                .font(.system(size: 11)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40)
        } else if let details = store.pokemonDetailsByID[selectedID] {
            VStack(spacing: 8) {
                PokemonNameLabel(items: details.types.map {
                    PokemonNameItem(resource: .init(kind: .type, name: $0))
                }, language: store.language)
                    .font(.system(size: 11, weight: .bold)).textCase(.uppercase)
                HStack(spacing: 20) {
                    lcdValue(l.height, String(format: "%.1f m", Double(details.height) / 10))
                    lcdValue(l.weight, String(format: "%.1f kg", Double(details.weight) / 10))
                }
            }
        } else if store.failedPokemonDetailIDs.contains(selectedID) {
            Text(l.pokemonDetailsUnavailable).font(.system(size: 11)).multilineTextAlignment(.center)
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(l.loadingPokemonDetails).font(.system(size: 11))
            }.frame(minHeight: 40)
        }
    }

    private var scanControls: some View {
        HStack(spacing: 8) {
            hardwareButton("Previous entry", symbol: "chevron.left") { moveSelection(-1) }
                .disabled(!canMove(-1))
            hardwareButton("Next entry", symbol: "chevron.right") { moveSelection(1) }
                .disabled(!canMove(1))
            Spacer(minLength: 0)
            Button {
                Task { await store.loadPokemonDetails(speciesID: selectedID) }
            } label: { Label("Scan", systemImage: "viewfinder").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(PokedexHardwareButtonStyle())
                .disabled(selectedSpecies == nil || store.loadingPokemonDetailIDs.contains(selectedID))
            Button { showingDetails = true } label: {
                Text("Details").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(PokedexHardwareButtonStyle(green: true))
            .disabled(selectedSpecies == nil)
            .accessibilityLabel("Pokémon profile, stats, and moves")
        }
    }

    private func individualReadout(_ entry: DexEntry) -> some View {
        let profile = entry.profile
        let progress = store.individualTrainingProgress(entryID: entry.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Individual record", systemImage: "person.text.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(individualStatus(entry)).font(.system(size: 10, weight: .bold))
            }
            if individuals.count > 1 {
                Picker(l.pokemonIndividual, selection: Binding(
                    get: { selectedIndividual?.id ?? "" }, set: { selectedInstanceID = $0 }
                )) {
                    ForEach(Array(individuals.enumerated()), id: \.element.id) { index, individual in
                        Text("#\(index + 1) · Lv. \(individual.profile?.level ?? 5) · \(individualStatus(individual))")
                            .tag(individual.id)
                    }
                }.pickerStyle(.menu).labelsHidden().colorScheme(.light)
            }
            HStack(spacing: 14) {
                lcdValue(l.level, "\(profile?.level ?? 5)")
                lcdValue("Catches", "\(entry.catchCount)")
                lcdValue("Catch XP", TokenFormatter.grouped(entry.repeatCatchXP))
            }
            if let progress {
                HStack {
                    Text("Training to graduation")
                    Spacer()
                    Text(progress.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit()
                }.font(.system(size: 10))
                PokedexProgressBar(progress: progress)
                    .accessibilityLabel("Training to graduation")
                    .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
            }
            if let profile {
                Text("\(TokenFormatter.grouped(profile.growthTokens)) training XP")
                    .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(12)
        .foregroundStyle(PokedexPalette.ink)
        .background(PokedexPalette.readout, in: RoundedRectangle(cornerRadius: 8))
    }

    private var registry: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker("Pokémon variant", selection: $variant) {
                    Text("Normal").tag(PokedexVariant.normal)
                    Text(l.dexShinyLabel).tag(PokedexVariant.shiny)
                }.pickerStyle(.segmented)
                Picker("Pokédex region", selection: $region) {
                    ForEach(PokedexRegion.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu).labelsHidden().fixedSize()
            }
            .colorScheme(.light)
            VStack(spacing: 10) {
                HStack {
                    Text(showingCatchLog ? "CATCH RECORDS" : "NATIONAL REGISTRY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                    Spacer()
                    Text(showingCatchLog ? "\(records.count)" : "\(registeredCount) / \(region.speciesIDs.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").accessibilityHidden(true)
                    TextField("Name or Pokédex number", text: $query).textFieldStyle(.plain)
                        .font(.system(size: 12)).accessibilityLabel("Find a Pokémon by name or number")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear Pokémon search")
                    }
                }
                .padding(8).background(PokedexPalette.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
                if !showingCatchLog {
                    Picker("Registration status", selection: $registrationFilter) {
                        ForEach(RegistrationFilter.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Rectangle().fill(PokedexPalette.ink.opacity(0.2)).frame(height: 1).accessibilityHidden(true)
                registryList
            }
            .padding(12)
            .foregroundStyle(PokedexPalette.ink)
            .background(PokedexPalette.lcd, in: RoundedRectangle(cornerRadius: 8))
            .padding(8)
            .background(PokedexPalette.rim.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var registryList: some View {
        let ids = registryIDs
        let names = speciesByID
        let known = registeredIDs
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if showingCatchLog {
                        if records.isEmpty { emptyRegistry("No catches in this view yet.") }
                        ForEach(records) { entry in
                            recordRow(entry).id(entry.id)
                        }
                    } else {
                        if ids.isEmpty { emptyRegistry("No matching entries.") }
                        ForEach(ids, id: \.self) { id in
                            registryRow(id: id, species: names[id], registered: known.contains(id)).id(id)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
            .frame(height: spacious ? 388 : 250)
            .onChange(of: selectedID) { _, id in
                if !showingCatchLog { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear { if !showingCatchLog { proxy.scrollTo(selectedID, anchor: .center) } }
        }
    }

    private func registryRow(id: Int, species: CompanionStore.DexSpecies?, registered: Bool) -> some View {
        Button { selectSpecies(id) } label: {
            HStack(spacing: 10) {
                Text(String(format: "%03d", id)).font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(width: 29, alignment: .leading)
                if registered {
                    SpriteView(speciesID: id, size: 30, shiny: variant == .shiny, unownForm: species?.unownForm)
                        .frame(width: 30, height: 30).accessibilityHidden(true)
                } else {
                    Image(systemName: "circle.dashed").font(.system(size: 18))
                        .frame(width: 30, height: 30).opacity(0.4).accessibilityHidden(true)
                }
                Text(registered ? (species?.name ?? "#\(id)") : "— — —")
                    .font(.system(size: 12, weight: registered ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 3)
                if registered {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selectedID == id ? PokedexPalette.ink.opacity(0.14) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(String(format: "%03d", id)), \(registered ? (species?.name ?? "Pokémon") : "Unregistered")")
        .accessibilityValue(registered ? "Registered" : "Unregistered")
        .accessibilityAddTraits(selectedID == id ? .isSelected : [])
    }

    private func recordRow(_ entry: DexEntry) -> some View {
        let selected = selectedID == entry.finalID && selectedIndividual?.id == entry.id
        return Button { selectSpecies(entry.finalID, instanceID: entry.id) } label: {
            HStack(spacing: 9) {
                SpriteView(speciesID: entry.finalID, size: 32, shiny: entry.isShiny, unownForm: entry.unownForm)
                    .frame(width: 32, height: 32).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recordName(entry)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text("\(individualStatus(entry)) · \(entry.catchCount) \(entry.catchCount == 1 ? "catch" : "catches")")
                        .font(.system(size: 10))
                    if let caughtAt = entry.caughtAt {
                        Text(caughtAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 9)).opacity(0.7)
                    }
                }
                Spacer(minLength: 0)
                Text(String(format: "#%03d", entry.finalID)).font(.system(size: 9, design: .monospaced))
            }
            .padding(8)
            .background(selected ? PokedexPalette.ink.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var hinge: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(colors: [PokedexPalette.rim, PokedexPalette.red, PokedexPalette.rim],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 12, height: 430)
            .overlay(alignment: .top) { Capsule().fill(.black.opacity(0.25)).frame(height: 3).padding(.top, 28) }
            .overlay(alignment: .bottom) { Capsule().fill(.black.opacity(0.25)).frame(height: 3).padding(.bottom, 28) }
            .accessibilityHidden(true)
    }

    private var deviceFooter: some View {
        HStack(spacing: 10) {
            Text(variant == .shiny ? "SHINY DATA" : "NORMAL DATA")
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
            Spacer()
            Text("\(registeredCount) REGISTERED")
                .font(.system(size: 9, design: .monospaced))
            screw
        }.foregroundStyle(.white.opacity(0.8))
    }

    private var screw: some View {
        Circle().fill(PokedexPalette.rim)
            .overlay { Rectangle().fill(.white.opacity(0.4)).frame(width: 6, height: 1).rotationEffect(.degrees(-35)) }
            .frame(width: 11, height: 11).accessibilityHidden(true)
    }
    private func indicator(_ color: Color) -> some View {
        Circle().fill(color).overlay { Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1) }
            .frame(width: 8, height: 8)
    }
    private func lcdValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9)).opacity(0.7)
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
        }
    }
    private func hardwareButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 12, weight: .bold)) }
            .buttonStyle(PokedexHardwareButtonStyle()).accessibilityLabel(label)
    }
    private func emptyRegistry(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2)
            Text(message).font(.system(size: 12)).multilineTextAlignment(.center)
            if !query.isEmpty {
                Button { query = "" } label: { Text("Clear search").underline() }.buttonStyle(.plain)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 30)
    }
    private func matchesQuery(id: Int, name: String?) -> Bool {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let search = input.hasPrefix("#") ? String(input.dropFirst()).trimmingCharacters(in: .whitespaces) : input
        return search.isEmpty || "\(id) \(String(format: "%03d", id)) \(name ?? "")".localizedCaseInsensitiveContains(search)
    }
    private func recordName(_ entry: DexEntry) -> String {
        let name = store.dexStoredChainNames(entry)?[entry.finalID] ?? speciesByID[entry.finalID]?.name ?? "#\(entry.finalID)"
        return UnownForm.displayName(name, speciesID: entry.finalID, form: entry.unownForm)
    }
    private func individualStatus(_ entry: DexEntry) -> String {
        if store.isActiveDexEntry(entry) { return l.dexRaising }
        if store.individualTrainingProgress(entryID: entry.id) != nil { return "Stored" }
        return entry.isReleased ? l.dexReleased : "Graduated"
    }
    private func selectSpecies(_ id: Int, instanceID: String? = nil) {
        selectedID = id
        selectedInstanceID = instanceID
        showingDetails = false
    }
    private func canMove(_ direction: Int) -> Bool {
        if showingCatchLog {
            let entries = records
            guard let index = entries.firstIndex(where: { $0.id == selectedIndividual?.id }) else { return false }
            return entries.indices.contains(index + direction)
        }
        guard let index = browserIDs.firstIndex(of: selectedID) else { return false }
        return browserIDs.indices.contains(index + direction)
    }
    private func moveSelection(_ direction: Int) {
        if showingCatchLog {
            let entries = records
            guard let index = entries.firstIndex(where: { $0.id == selectedIndividual?.id }),
                  entries.indices.contains(index + direction) else { return }
            let next = entries[index + direction]
            selectSpecies(next.finalID, instanceID: next.id)
            return
        }
        let ids = browserIDs
        guard let index = ids.firstIndex(of: selectedID), ids.indices.contains(index + direction) else { return }
        selectSpecies(ids[index + direction])
    }
}

private enum PokedexPalette {
    static let red = Color(red: 0.79, green: 0.16, blue: 0.22)
    static let deepRed = Color(red: 0.60, green: 0.07, blue: 0.15)
    static let rim = Color(red: 0.38, green: 0.05, blue: 0.11)
    static let sensor = Color(red: 0.13, green: 0.72, blue: 0.92)
    static let lampRed = Color(red: 0.99, green: 0.41, blue: 0.37)
    static let lampYellow = Color(red: 1, green: 0.80, blue: 0.31)
    static let lampGreen = Color(red: 0.47, green: 0.84, blue: 0.39)
    static let bezel = Color(red: 0.87, green: 0.88, blue: 0.84)
    static let lcd = Color(red: 0.78, green: 0.86, blue: 0.62)
    static let readout = Color(red: 0.66, green: 0.77, blue: 0.45)
    static let ink = Color(red: 0.14, green: 0.23, blue: 0.14)
    static let detail = Color(red: 0.96, green: 0.97, blue: 0.91)
}

private struct PokedexHardwareButtonStyle: ButtonStyle {
    var green = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 11).padding(.vertical, 9)
            .foregroundStyle(green ? PokedexPalette.ink : .white)
            .background(green ? PokedexPalette.readout : PokedexPalette.ink,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(.black.opacity(0.25), lineWidth: 1) }
            .shadow(color: .black.opacity(0.2), radius: 0, y: configuration.isPressed ? 0 : 2)
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(enabled ? 1 : 0.45)
    }
}

private struct PokedexProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(PokedexPalette.ink.opacity(0.18))
                .overlay(alignment: .leading) {
                    Capsule().fill(PokedexPalette.ink)
                        .frame(width: geometry.size.width * min(1, max(0, progress)))
                }
        }.frame(height: 5)
    }
}

private struct PokedexScanGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for column in 1..<8 {
            let x = rect.width * CGFloat(column) / 8
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for row in 1..<5 {
            let y = rect.height * CGFloat(row) / 5
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
