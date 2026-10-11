import XCTest
@testable import PokeTaskBar

final class PokedexRegistryTests: XCTestCase {
    func testRegionalRegistriesPartitionSupportedNationalDex() {
        let regionalIDs = PokedexRegion.allCases.filter { $0 != .national }.flatMap { Array($0.speciesIDs) }
        XCTAssertEqual(regionalIDs, Array(PokemonAssets.animatedSpeciesIDs))
        XCTAssertEqual(Set(regionalIDs).count, regionalIDs.count)
    }

    func testShinyAndNormalDiscoveriesAreIndependent() {
        let normal = DexEntry(baseID: 1, finalID: 3, chainOrder: [1, 2, 3], rarity: .common, caughtAt: nil)
        let shiny = DexEntry(baseID: 4, finalID: 6, chainOrder: [4, 5, 6], rarity: .common,
                             caughtAt: nil, isShiny: true)
        let registry = PokedexRegistration(records: [normal, shiny], partners: [])
        XCTAssertEqual(registry.speciesIDs(for: .normal), [1, 2, 3])
        XCTAssertEqual(registry.speciesIDs(for: .shiny), [4, 5, 6])
        XCTAssertFalse(registry.contains(4, variant: .normal))
        XCTAssertFalse(registry.contains(1, variant: .shiny))
    }

    func testActiveAndStoredPartnersRegisterOnlyReachedForms() {
        let active = MonState(baseID: 1, pathIDs: [1, 2, 3], stageIndex: 0, usedAtStage: 0,
                              rarity: .common, totalForms: 3)
        let stored = MonState(baseID: 4, pathIDs: [4, 5, 6], stageIndex: 1, usedAtStage: 0,
                              rarity: .common, totalForms: 3, isShiny: true)
        let registry = PokedexRegistration(records: [], partners: [active, stored])
        XCTAssertEqual(registry.speciesIDs(for: .normal), [1])
        XCTAssertEqual(registry.speciesIDs(for: .shiny), [4, 5])
        XCTAssertFalse(registry.contains(2, variant: .normal))
        XCTAssertFalse(registry.contains(6, variant: .shiny))
    }

    func testUnrevealedDittoDoesNotExposeShinyIdentity() {
        var disguised = MonState(baseID: 1, pathIDs: [1], stageIndex: 0, usedAtStage: 0,
                                  rarity: .common, totalForms: 2, isShiny: true, dittoDisguise: 1)
        let hidden = PokedexRegistration(records: [], partners: [disguised])
        XCTAssertTrue(hidden.contains(1, variant: .normal))
        XCTAssertFalse(hidden.contains(1, variant: .shiny))

        disguised.baseID = PokemonOdds.dittoSpeciesID
        disguised.pathIDs = [PokemonOdds.dittoSpeciesID]
        disguised.dittoRevealed = true
        let revealed = PokedexRegistration(records: [], partners: [disguised])
        XCTAssertTrue(revealed.contains(PokemonOdds.dittoSpeciesID, variant: .shiny))
        XCTAssertFalse(revealed.contains(1, variant: .normal))
    }

    func testUnsupportedSpeciesStayOutsideRegistry() {
        let imported = DexEntry(baseID: 650, finalID: 652, chainOrder: [650, 651, 652],
                                rarity: .common, caughtAt: nil)
        let registry = PokedexRegistration(records: [imported], partners: [])
        XCTAssertTrue(registry.speciesIDs(for: .normal).isEmpty)
    }
}
