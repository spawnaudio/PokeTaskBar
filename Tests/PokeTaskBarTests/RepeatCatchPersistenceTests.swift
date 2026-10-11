import XCTest
@testable import PokeTaskBar

final class RepeatCatchPersistenceTests: XCTestCase {
    private func partner(_ id: String = "original", shiny: Bool = false,
                         base: Int = 1, form: UnownForm? = nil) -> MonState {
        MonState(baseID: base, pathIDs: [base], stageIndex: 0, usedAtStage: 123,
                 rarity: .common, totalForms: 1, isShiny: shiny,
                 profile: PokemonProfile.generate(seed: 42, instanceID: id), unownForm: form,
                 catchCount: 3, repeatCatchXP: 50_123)
    }

    func testLegacyIndividualsDecodeWithFirstCatchAndNoRepeatXP() throws {
        let legacyMon = #"{"baseID":1,"pathIDs":[1],"stageIndex":0,"usedAtStage":123,"rarity":"common","totalForms":1}"#
        let mon = try JSONDecoder().decode(MonState.self, from: Data(legacyMon.utf8))
        XCTAssertEqual(mon.catchCount, 1)
        XCTAssertEqual(mon.repeatCatchXP, 0)
        let legacyEntry = #"{"baseID":1,"finalID":1,"chainOrder":[1],"rarity":"common"}"#
        let entry = try JSONDecoder().decode(DexEntry.self, from: Data(legacyEntry.utf8))
        XCTAssertEqual(entry.catchCount, 1)
        XCTAssertEqual(entry.repeatCatchXP, 0)
    }

    func testMalformedNewHistoryDoesNotDiscardExistingIndividual() throws {
        let malformed = #"{"baseID":1,"pathIDs":[1],"stageIndex":0,"usedAtStage":123,"rarity":"common","totalForms":1,"catchCount":"oops","repeatCatchXP":[]}"#
        let mon = try JSONDecoder().decode(MonState.self, from: Data(malformed.utf8))
        XCTAssertEqual(mon.usedAtStage, 123)
        XCTAssertEqual(mon.catchCount, 1)
        XCTAssertEqual(mon.repeatCatchXP, 0)
    }

    func testSaveTransferKeepsActiveStoredGraduatedAndReleasedCatchHistory() throws {
        var state = CompanionState()
        state.active = partner("active")
        state.pokemonStorage = [.partner(id: "banked", mon: partner("banked")), .egg(id: "egg", tier: .rare, usage: 100)]
        state.dex = [
            DexEntry(id: "graduate", baseID: 1, finalID: 1, chainOrder: [1], rarity: .common,
                     caughtAt: nil, profile: PokemonProfile.generate(seed: 5, instanceID: "graduate"),
                     catchCount: 4, repeatCatchXP: 100_321),
            DexEntry(id: "release", baseID: 4, finalID: 4, chainOrder: [4], rarity: .common,
                     caughtAt: nil, releasedAt: Date(timeIntervalSince1970: 123), catchCount: 2, repeatCatchXP: 50_000)
        ]
        let data = try SaveTransfer.encode(state: state, appVersion: "v4", deviceName: "test", now: Date())
        let restored = try SaveTransfer.decode(data).state
        XCTAssertEqual(restored.active, state.active)
        XCTAssertEqual(restored.pokemonStorage, state.pokemonStorage)
        XCTAssertEqual(restored.dex, state.dex)
    }

    func testImportedStorageUsesSameSafetyBoundsAsActivePartner() throws {
        var mon = partner("reserved-instance")
        let ivs = mon.profile?.ivs
        mon.usedAtStage = Int.max
        mon.totalForms = Int.max
        mon.stageIndex = Int.max
        mon.catchCount = Int.max
        mon.repeatCatchXP = Int.max
        var state = CompanionState()
        state.active = mon
        state.pokemonStorage = [.partner(id: "reserved-instance", mon: mon),
                                .egg(id: "reserved-egg", tier: .legendary, usage: Int.max)]
        state.bonusXP = Int.max
        let clean = SaveTransfer.sanitized(state)
        guard case .partner(let id, let stored) = clean.pokemonStorage[0],
              case .egg(let eggID, let tier, let usage) = clean.pokemonStorage[1] else {
            return XCTFail("sanitizing preserves storage item kinds")
        }
        XCTAssertEqual(stored, clean.active)
        XCTAssertEqual(id, "reserved-instance")
        XCTAssertEqual(stored.profile?.instanceID, id)
        XCTAssertEqual(stored.profile?.ivs, ivs)
        XCTAssertEqual(stored.usedAtStage, SaveTransfer.maxTokenValue)
        XCTAssertEqual(stored.totalForms, 12)
        XCTAssertEqual(stored.stageIndex, 0)
        XCTAssertEqual(stored.catchCount, SaveTransfer.maxTokenValue)
        XCTAssertEqual(stored.repeatCatchXP, SaveTransfer.maxTokenValue)
        XCTAssertEqual(eggID, "reserved-egg")
        XCTAssertNil(tier, "an impossible stored guarantee must not block a later swap")
        XCTAssertEqual(usage, SaveTransfer.maxTokenValue)
        XCTAssertEqual(clean.bonusXP, SaveTransfer.maxTokenValue)
    }

    func testNegativeImportedCatchHistoryAndEggXPUseSafeDefaults() {
        var mon = partner()
        mon.catchCount = -4
        mon.repeatCatchXP = -500
        var state = CompanionState()
        state.pokemonStorage = [.partner(id: "original", mon: mon), .egg(id: "egg", tier: .rare, usage: -100)]
        state.dex = [DexEntry(baseID: 1, finalID: 1, chainOrder: [1], rarity: .common,
                              caughtAt: nil, catchCount: -4, repeatCatchXP: -1)]
        let clean = SaveTransfer.sanitized(state)
        guard case .partner(_, let stored) = clean.pokemonStorage[0],
              case .egg(_, let tier, let usage) = clean.pokemonStorage[1] else { return XCTFail("missing storage") }
        XCTAssertEqual(stored.catchCount, 1)
        XCTAssertEqual(stored.repeatCatchXP, 0)
        XCTAssertEqual(clean.dex.first?.catchCount, 1)
        XCTAssertEqual(clean.dex.first?.repeatCatchXP, 0)
        XCTAssertEqual(tier, .rare)
        XCTAssertEqual(usage, 0)
    }

    func testStoredShinyRemainsRegisteredWhileHiddenDittoColourIsPrivate() {
        var hidden = partner("ditto", shiny: true, base: 4)
        hidden.dittoDisguise = 4
        var state = CompanionState()
        state.pokemonStorage = [.partner(id: "normal-shiny", mon: partner("normal-shiny", shiny: true)),
                                .partner(id: "ditto", mon: hidden)]
        XCTAssertTrue(state.ownsShinySpecies(1))
        XCTAssertTrue(state.ownsSpecies(1, shinyOnly: true))
        XCTAssertFalse(state.ownsShinySpecies(4))
        XCTAssertFalse(state.ownsSpecies(4, shinyOnly: true))
        XCTAssertTrue(state.ownsSpecies(4), "the visible disguise is still a normal discovery")
    }

    func testStoredUnownFormsKeepWeightsAndRepresentativeOwnership() {
        var state = CompanionState()
        state.pokemonStorage = [.partner(id: "letter", mon: partner("letter", base: 201, form: .question))]
        state.representativeSpeciesID = 201
        state.representativeUnownForm = .question
        state.reconcileRepresentativeSelection()
        XCTAssertEqual(state.collectedUnownForms, [.question])
        XCTAssertEqual(state.representativeSpeciesID, 201)
        XCTAssertEqual(state.representativeUnownForm, .question)
        XCTAssertFalse(state.ownsSpecies(201, unownForm: .a))
    }
}
