import XCTest
@testable import PokeTaskBar

private struct RepeatTrainingProvider: PokeProviding {
    var forms = 3
    func line(baseSpeciesID: Int) async throws -> EvoLine {
        let ids = Array(baseSpeciesID..<(baseSpeciesID + forms))
        var tree = EvoNode(speciesID: ids.last!, children: [])
        for id in ids.dropLast().reversed() { tree = EvoNode(speciesID: id, children: [tree]) }
        return EvoLine(baseID: baseSpeciesID, tree: tree, rarity: .common, names: [:])
    }
    func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: 1, captureRate: 255)] }
}

@MainActor
final class RepeatCatchIntegrationTests: XCTestCase {
    private func partner(_ id: String, base: Int = 1, stage: Int = 0, used: Int = 123,
                         shiny: Bool = false, forms: Int = 3, form: UnownForm? = nil,
                         ditto: Bool = false) -> MonState {
        let path = Array(base...(base + stage))
        return MonState(baseID: base, pathIDs: path,
                        plannedPathIDs: Array(base..<(base + forms)), stageIndex: stage,
                        usedAtStage: used, rarity: .common, totalForms: forms,
                        isShiny: shiny, nature: .hardy,
                        profile: PokemonProfile.generate(seed: 42, instanceID: id),
                        dittoDisguise: ditto ? base : nil, unownForm: form,
                        catchCount: 2, repeatCatchXP: 100)
    }

    private func fixture(_ seedState: CompanionState, seed: UInt64 = 1,
                         forms: Int = 3, ditto: Bool = false) throws -> (CompanionStore, URL, UserDefaults) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("repeat-training-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("state.json")
        try JSONEncoder().encode(seedState).write(to: file)
        let suite = "repeat-training-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(1.0, forKey: "growthDifficulty")
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return (CompanionStore(provider: RepeatTrainingProvider(forms: forms), fileURL: file,
                               rng: SeededRNG(seed: seed), dittoDisguiseRollingEnabled: ditto,
                               defaults: defaults), file, defaults)
    }

    func testRepeatCatchResumesEvolvedFamilyWithOriginalIdentityAndRoute() async throws {
        var state = CompanionState()
        state.eggUsage = PokemonBalance.eggHatchThreshold + 321
        state.usedSinceInstall = 20_000_000
        state.bonusXP = 123_456
        state.spentTokens = 100
        state.pokemonStorage = [.partner(id: "evolved", mon: partner("evolved", stage: 1, used: 456))]
        let (store, file, defaults) = try fixture(state)
        let previous = try XCTUnwrap(store.pokemonIndividuals(speciesID: 2).first?.profile)
        let lifetimeXP = store.lifetimeXP
        let coins = store.availableCoins
        await store.hatch(baseID: 1)
        let resumed = try XCTUnwrap(store.state.active)
        XCTAssertEqual(resumed.baseID, 1)
        XCTAssertEqual(resumed.currentID, 2)
        XCTAssertEqual(resumed.pathIDs, [1, 2])
        XCTAssertEqual(resumed.plannedPathIDs, [1, 2, 3])
        XCTAssertEqual(resumed.stageIndex, 1)
        XCTAssertEqual(resumed.usedAtStage, 456 + state.eggUsage)
        XCTAssertEqual(resumed.nature, .hardy)
        XCTAssertEqual(resumed.profile?.instanceID, previous.instanceID)
        XCTAssertEqual(resumed.profile?.ivs, previous.ivs)
        XCTAssertGreaterThan(resumed.profile?.growthTokens ?? 0, previous.growthTokens)
        XCTAssertEqual(resumed.catchCount, 3)
        XCTAssertEqual(resumed.repeatCatchXP, 100 + state.eggUsage)
        XCTAssertTrue(store.storedCompanions.isEmpty)
        XCTAssertEqual(store.lifetimeXP, lifetimeXP)
        XCTAssertEqual(store.availableCoins, coins)
        let reload = CompanionStore(provider: RepeatTrainingProvider(), fileURL: file, defaults: defaults)
        XCTAssertEqual(reload.state.active, resumed)
    }

    func testRepeatCatchXPGraduatesAndResumesOtherPartnerWithoutSpillover() async throws {
        var state = CompanionState()
        state.eggUsage = PokemonBalance.eggHatchThreshold + 123
        let finalThreshold = PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 2)
        state.pokemonStorage = [
            .partner(id: "graduate", mon: partner("graduate", stage: 2, used: finalThreshold - 100)),
            .partner(id: "next", mon: partner("next", base: 4, used: 777))
        ]
        let (store, _, _) = try fixture(state)
        let next = try XCTUnwrap(store.pokemonIndividuals(speciesID: 4).first?.profile)
        await store.hatch(baseID: 1)
        let graduated = try XCTUnwrap(store.state.dex.last)
        XCTAssertEqual(graduated.profile?.instanceID, "graduate")
        XCTAssertEqual(graduated.profile?.level, 100)
        XCTAssertEqual(graduated.profile?.growthTokens, PokemonBalance.graduationTotal(.common))
        XCTAssertEqual(graduated.catchCount, 3)
        XCTAssertEqual(graduated.repeatCatchXP, 100 + state.eggUsage)
        XCTAssertEqual(store.state.active?.profile, next)
        XCTAssertEqual(store.state.active?.usedAtStage, 777)
        XCTAssertEqual(store.state.active?.catchCount, 2)
        XCTAssertTrue(store.storedCompanions.isEmpty)
        XCTAssertNil(store.individualTrainingProgress(entryID: graduated.id))
    }

    func testNormalCatchCreatesIndividualWhenOnlyMatchingShinyIsStored() async throws {
        var state = CompanionState()
        state.eggUsage = PokemonBalance.eggHatchThreshold
        state.pokemonStorage = [.partner(id: "shiny", mon: partner("shiny", shiny: true))]
        let (store, _, _) = try fixture(state)
        let banked = store.storedCompanions
        await store.hatch(baseID: 1)
        XCTAssertFalse(store.currentIsShiny)
        XCTAssertNotEqual(store.state.active?.profile?.instanceID, "shiny")
        XCTAssertEqual(store.state.active?.catchCount, 1)
        XCTAssertEqual(store.state.active?.repeatCatchXP, 0)
        XCTAssertEqual(store.storedCompanions, banked)
    }

    func testHiddenDittoPartnerDoesNotAbsorbNormalDisguiseSpecies() async throws {
        var state = CompanionState()
        state.eggUsage = PokemonBalance.eggHatchThreshold
        state.pokemonStorage = [.partner(id: "ditto", mon: partner("ditto", ditto: true))]
        let (store, _, _) = try fixture(state)
        let banked = store.storedCompanions
        await store.hatch(baseID: 1)
        XCTAssertNil(store.state.active?.dittoDisguise)
        XCTAssertNotEqual(store.state.active?.profile?.instanceID, "ditto")
        XCTAssertEqual(store.storedCompanions, banked)
    }

    func testIncomingDittoDisguiseDoesNotBecomeRepeatCatchXP() async throws {
        let seed = try XCTUnwrap((UInt64(1)...100_000).first { seed in
            var rng = SeededRNG(seed: seed)
            guard !CompanionStore.rollsShiny(roll: rng.next(), charmOwned: false) else { return false }
            _ = rng.next() // Nature precedes the disguise roll.
            return CompanionStore.dittoDisguiseHit(rarity: .common, totalForms: 3, roll: rng.next())
        })
        var state = CompanionState()
        state.eggUsage = PokemonBalance.eggHatchThreshold
        state.pokemonStorage = [.partner(id: "normal", mon: partner("normal"))]
        let (store, _, _) = try fixture(state, seed: seed, ditto: true)
        let banked = store.storedCompanions
        await store.hatch(baseID: 1)
        XCTAssertEqual(store.state.active?.dittoDisguise, 1)
        XCTAssertNotEqual(store.state.active?.profile?.instanceID, "normal")
        XCTAssertEqual(store.storedCompanions, banked)
    }

    func testUnownRepeatCatchRequiresSamePendingLetter() async throws {
        for letter in [UnownForm.a, .b] {
            var state = CompanionState()
            state.eggUsage = PokemonBalance.eggHatchThreshold + 123
            state.pendingHatchID = 201
            state.pendingUnownForm = letter
            state.pokemonStorage = [.partner(id: "letter-a", mon: partner("letter-a", base: 201, forms: 1, form: .a))]
            let (store, _, _) = try fixture(state, forms: 1)
            await store.hatchIfNeeded()
            XCTAssertEqual(store.currentUnownForm, letter)
            if letter == .a {
                XCTAssertEqual(store.state.active?.profile?.instanceID, "letter-a")
                XCTAssertEqual(store.state.active?.repeatCatchXP, 100 + state.eggUsage)
                XCTAssertTrue(store.storedCompanions.isEmpty)
            } else {
                XCTAssertNotEqual(store.state.active?.profile?.instanceID, "letter-a")
                XCTAssertEqual(store.state.active?.repeatCatchXP, 0)
                XCTAssertEqual(store.storedCompanions.count, 1)
            }
        }
    }

    func testDifficultyChangesRepriceStoredPartnerAndEggBeforeSwapAndReload() async throws {
        let threshold = PokemonBalance.phaseThreshold(rarity: .common, totalForms: 3, stageIndex: 0)
        var state = CompanionState()
        state.active = partner("current", base: 4, used: threshold / 2)
        state.pokemonStorage = [.partner(id: "banked", mon: partner("banked", used: threshold / 4)),
                                .egg(id: "egg", tier: .rare, usage: PokemonBalance.eggHatchThreshold / 2)]
        let (store, file, defaults) = try fixture(state)
        let original = try XCTUnwrap(store.pokemonIndividuals(speciesID: 1).first?.profile)
        store.setGrowthDifficulty(2)
        store.setGrowthDifficulty(0.1)
        guard case .partner(_, let mon) = store.storedCompanions[0],
              case .egg(_, let tier, let usage) = store.storedCompanions[1] else { return XCTFail("missing banked items") }
        XCTAssertEqual(mon.usedAtStage, PokemonBalance.scaled(threshold, by: 0.1) / 4)
        XCTAssertEqual(mon.profile, original)
        XCTAssertEqual(tier, .rare)
        XCTAssertEqual(usage, PokemonBalance.scaled(PokemonBalance.eggHatchThreshold, by: 0.1) / 2)
        let reload = CompanionStore(provider: RepeatTrainingProvider(), fileURL: file, defaults: defaults)
        XCTAssertEqual(reload.storedCompanions, store.storedCompanions)
        XCTAssertTrue(reload.swapFromStorage("banked"))
        for _ in 0..<200 { if reload.currentLine != nil { break }; await Task.yield() }
        XCTAssertEqual(reload.state.active?.profile, original)
        XCTAssertEqual(reload.state.active?.usedAtStage, mon.usedAtStage)
        XCTAssertEqual(reload.progress, 0.25, accuracy: 0.000001)
    }

    func testLegacyStoredProfileMigrationKeepsReservedIdentityAndEarnedGrowth() throws {
        var mon = partner("reserved")
        mon.profile = nil
        var state = CompanionState()
        state.pokemonStorage = [.partner(id: "reserved", mon: mon)]
        let (store, file, defaults) = try fixture(state)
        let profile = try XCTUnwrap(store.pokemonIndividuals(speciesID: 1).first?.profile)
        XCTAssertEqual(profile.instanceID, "reserved")
        XCTAssertGreaterThan(profile.growthTokens, 0)
        let reload = CompanionStore(provider: RepeatTrainingProvider(), fileURL: file, defaults: defaults)
        XCTAssertEqual(reload.storedCompanions, store.storedCompanions)
    }

    func testCatchLogIncludesActiveBankedAndHistoricalIndividualsWithoutStoredEggs() throws {
        var state = CompanionState()
        state.active = partner("active")
        state.pokemonStorage = [.egg(id: "egg", tier: nil, usage: 100),
                                .partner(id: "banked", mon: partner("banked", base: 4))]
        state.dex = [DexEntry(id: "graduate", baseID: 7, finalID: 9, chainOrder: [7, 8, 9],
                              rarity: .common, caughtAt: Date(timeIntervalSince1970: 1),
                              profile: PokemonProfile.generate(seed: 43, instanceID: "graduate"))]
        let (store, _, _) = try fixture(state)
        XCTAssertEqual(store.pokemonCatchLogEntries.map(\.id), ["active-1-1", "banked", "graduate"])
        XCTAssertEqual(Set(store.pokemonCatchLogEntries.map(\.id)).count, 3)
        XCTAssertEqual(store.pokemonIndividuals(speciesID: 4).map(\.id), ["banked"])
        XCTAssertNotNil(store.individualTrainingProgress(entryID: "banked"))
        XCTAssertNil(store.individualTrainingProgress(entryID: "graduate"))
    }
}
