import XCTest
@testable import PokeTaskBar

@MainActor
final class PokemonDetailSelectionTests: XCTestCase {
    func testCatchRecordOpensItsUnownFormBeforeRepresentativeForm() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pokedex-detail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let suite = "pokedex-detail-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var state = CompanionState()
        state.dex = [
            DexEntry(id: "normal-a", baseID: 201, finalID: 201, chainOrder: [201], rarity: .common,
                     caughtAt: nil, unownForm: .a),
            DexEntry(id: "shiny-question", baseID: 201, finalID: 201, chainOrder: [201], rarity: .common,
                     caughtAt: nil, isShiny: true, unownForm: .question),
        ]
        try JSONEncoder().encode(state).write(to: url)
        let store = CompanionStore(fileURL: url, defaults: defaults)
        XCTAssertTrue(store.setRepresentativeSpeciesID(201, unownForm: .a))
        let species = try XCTUnwrap(store.dexSpecies.first { $0.id == 201 })
        let requested = PokemonDetailView(store: store, species: species,
                                         initialInstanceID: "shiny-question", onBack: {})
        XCTAssertEqual(requested.displayedSpecies.unownForm, .question)
        XCTAssertTrue(requested.displayedSpecies.isShiny)

        let defaultPage = PokemonDetailView(store: store, species: species, onBack: {})
        XCTAssertEqual(defaultPage.displayedSpecies.unownForm, .a)
    }
}
