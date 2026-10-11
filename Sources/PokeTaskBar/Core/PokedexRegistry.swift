import Foundation

enum PokedexVariant: String, CaseIterable, Identifiable {
    case normal, shiny
    var id: String { rawValue }
}

enum PokedexRegion: String, CaseIterable, Identifiable {
    case national, kanto, johto, hoenn, sinnoh, unova
    var id: String { rawValue }

    var title: String {
        switch self {
        case .national: "National"
        case .kanto: "Kanto"
        case .johto: "Johto"
        case .hoenn: "Hoenn"
        case .sinnoh: "Sinnoh"
        case .unova: "Unova"
        }
    }

    var speciesIDs: ClosedRange<Int> {
        switch self {
        case .national: PokemonAssets.animatedSpeciesIDs
        case .kanto: 1...151
        case .johto: 152...251
        case .hoenn: 252...386
        case .sinnoh: 387...493
        case .unova: 494...649
        }
    }
}

/// Registration follows discoveries, including reached forms of stored partners.
/// A shiny discovery registers the shiny catalogue independently of normal catches.
struct PokedexRegistration: Equatable, Sendable {
    private(set) var normalSpeciesIDs: Set<Int> = []
    private(set) var shinySpeciesIDs: Set<Int> = []

    init(records: [DexEntry], partners: [MonState]) {
        for entry in records {
            register(entry.chainOrder, shiny: entry.isShiny)
        }
        for partner in partners {
            // A saved evolution plan is not a discovery. Ditto's hidden colour is
            // likewise withheld until its identity has been revealed.
            let reached = Array(partner.pathIDs.prefix(max(0, partner.stageIndex + 1)))
            let visibleShiny = partner.isShiny
                && (partner.dittoDisguise == nil || partner.dittoRevealed)
            register(reached, shiny: visibleShiny)
        }
    }

    func speciesIDs(for variant: PokedexVariant) -> Set<Int> {
        variant == .shiny ? shinySpeciesIDs : normalSpeciesIDs
    }

    func contains(_ speciesID: Int, variant: PokedexVariant) -> Bool {
        speciesIDs(for: variant).contains(speciesID)
    }

    private mutating func register(_ ids: [Int], shiny: Bool) {
        let supported = ids.filter(PokemonAssets.hasAnimatedSprite(speciesID:))
        if shiny { shinySpeciesIDs.formUnion(supported) }
        else { normalSpeciesIDs.formUnion(supported) }
    }
}
