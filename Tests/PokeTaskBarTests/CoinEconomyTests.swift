import XCTest
@testable import PokeTaskBar

final class CoinEconomyTests: XCTestCase {
    func testSeedShopPricesMatchKickoffTable() {
        XCTAssertEqual(Mint.price, 1_000)
        XCTAssertEqual(RareCandy.price, 5_000)
        XCTAssertEqual(FreshEgg.price, 10_000)
        XCTAssertEqual(FreshEgg.price(guaranteeing: .uncommon), 25_000)
        XCTAssertEqual(ShinyCharm.price, 30_000)
        XCTAssertEqual(FreshEgg.price(guaranteeing: .rare), 40_000)
    }

    func testCoinsAreFloorXPOver1000() {
        XCTAssertEqual(EconomyScale.xpPerCoin, 1_000)
        XCTAssertEqual(EconomyScale.coinsFromXP(0), 0)
        XCTAssertEqual(EconomyScale.coinsFromXP(999), 0)
        XCTAssertEqual(EconomyScale.coinsFromXP(1_000), 1)
        XCTAssertEqual(EconomyScale.coinsFromXP(1_999), 1)
        XCTAssertEqual(EconomyScale.xpForCoins(5_000), 5_000_000)
    }
}

@MainActor
final class UniqueHatchTests: XCTestCase {
    private struct OneSpeciesProvider: PokeProviding {
        func line(baseSpeciesID: Int) async throws -> EvoLine {
            EvoLine(baseID: 1, tree: EvoNode(speciesID: 1, children: []),
                    rarity: .common, names: [1: ["en": "Bulba"]])
        }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { [BaseSpecies(id: 1, captureRate: 255)] }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { BaseSpecies(id: 1, captureRate: 255) }
    }

    private func eggStore(dexJSON: String, seed: UInt64) -> CompanionStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("unique-hatch-\(UUID())")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("state.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let suite = "unique-hatch-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(1.0, forKey: "growthDifficulty")
        defaults.set(1.0, forKey: "shopDifficulty")
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let json = "{\"installBaselineSet\":true,\"usedSinceInstall\":10000000,\"spentTokens\":0,"
            + "\"lastDate\":\"d\",\"active\":null,\"dex\":[\(dexJSON)],\"collectedFinals\":[],"
            + "\"eggUsage\":\(PokemonBalance.eggHatchThreshold)}"
        try? json.data(using: .utf8)!.write(to: url)
        return CompanionStore(provider: OneSpeciesProvider(), clock: { Date(timeIntervalSince1970: 1) },
                              fileURL: url, rng: SeededRNG(seed: seed),
                              dittoDisguiseRollingEnabled: false, defaults: defaults)
    }

    private func seed(shiny: Bool) throws -> UInt64 {
        try XCTUnwrap((UInt64(1)...10_000).first { seed in
            var rng = SeededRNG(seed: seed)
            return CompanionStore.rollsShiny(roll: rng.next(), charmOwned: false) == shiny
        })
    }

    func testGraduatedSpeciesAllowsFreshNormalAndShinyIndividuals() async throws {
        let dex = "{\"baseID\":1,\"finalID\":1,\"chainOrder\":[1],\"rarity\":\"common\"}"
        for shiny in [false, true] {
            let store = eggStore(dexJSON: dex, seed: try seed(shiny: shiny))
            let historical = store.state.dex
            await store.hatch(baseID: 1)
            XCTAssertEqual(store.state.active?.baseID, 1)
            XCTAssertEqual(store.currentIsShiny, shiny)
            XCTAssertEqual(store.state.active?.catchCount, 1)
            XCTAssertEqual(store.state.dex, historical, "a new catch cannot mutate graduated history")
        }
    }

    func testStoredNormalRepeatResumesIndividualAndAppliesFullEggXP() async throws {
        let normal = eggStore(dexJSON: "", seed: 1)
        await normal.hatch(baseID: 1)
        normal.applyUsage(100)
        let original = try XCTUnwrap(normal.state.active)
        XCTAssertFalse(original.isShiny)
        XCTAssertTrue(normal.buyFreshEgg())
        XCTAssertTrue(normal.storePartnerReplacingWithStoredEgg())
        XCTAssertTrue(normal.state.dex.isEmpty)
        XCTAssertTrue(normal.state.ownsSpecies(1))
        let beforeXP = normal.lifetimeXP
        let eggXP = PokemonBalance.eggHatchThreshold + 123
        normal.creditEarnedXP(eggXP, fromTokens: true)
        await normal.hatchIfNeeded()
        let resumed = try XCTUnwrap(normal.state.active)
        XCTAssertEqual(resumed.profile?.instanceID, original.profile?.instanceID)
        XCTAssertEqual(resumed.profile?.ivs, original.profile?.ivs)
        XCTAssertEqual(resumed.plannedPathIDs, original.plannedPathIDs)
        XCTAssertEqual(resumed.usedAtStage, original.usedAtStage + eggXP)
        XCTAssertEqual(resumed.catchCount, 2)
        XCTAssertEqual(resumed.repeatCatchXP, eggXP)
        XCTAssertEqual(normal.lifetimeXP, beforeXP + eggXP, "the hatch must not re-award earned wallet XP")
        XCTAssertTrue(normal.storedCompanions.isEmpty)
        XCTAssertEqual(normal.state.eggUsage, 0)

        let data = try SaveTransfer.encode(state: normal.state, appVersion: "v4", deviceName: "test", now: Date())
        let restored = try SaveTransfer.decode(data).state.active
        XCTAssertEqual(restored, resumed, "catch count, XP and original individual survive save transfer")
    }

    func testRepeatedShinyCatchesRemainSeparateFromNormalAndShinyPartners() async throws {
        let normal = eggStore(dexJSON: "", seed: 1)
        await normal.hatch(baseID: 1)
        XCTAssertTrue(normal.buyFreshEgg())
        XCTAssertTrue(normal.storePartnerReplacingWithStoredEgg())
        var saved = normal.state
        saved.usedSinceInstall = 30_000_000
        saved.eggUsage = PokemonBalance.eggHatchThreshold
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stored-hatch-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(saved).write(to: url)
        let firstShiny = CompanionStore(provider: OneSpeciesProvider(), fileURL: url,
                                        rng: SeededRNG(seed: try seed(shiny: true)), dittoDisguiseRollingEnabled: false)
        await firstShiny.hatch(baseID: 1)
        let firstID = try XCTUnwrap(firstShiny.state.active?.profile?.instanceID)
        XCTAssertTrue(firstShiny.currentIsShiny)
        XCTAssertEqual(firstShiny.storedCompanions.count, 1)
        XCTAssertTrue(firstShiny.buyFreshEgg())
        XCTAssertTrue(firstShiny.storePartnerReplacingWithStoredEgg())
        saved = firstShiny.state
        saved.eggUsage = PokemonBalance.eggHatchThreshold
        try JSONEncoder().encode(saved).write(to: url)
        let secondShiny = CompanionStore(provider: OneSpeciesProvider(), fileURL: url,
                                         rng: SeededRNG(seed: try seed(shiny: true)), dittoDisguiseRollingEnabled: false)
        let banked = secondShiny.storedCompanions
        await secondShiny.hatch(baseID: 1)
        XCTAssertTrue(secondShiny.currentIsShiny)
        XCTAssertNotEqual(secondShiny.state.active?.profile?.instanceID, firstID)
        XCTAssertEqual(secondShiny.state.active?.catchCount, 1)
        XCTAssertEqual(secondShiny.storedCompanions, banked)
        XCTAssertEqual(secondShiny.pokemonIndividuals(speciesID: 1).count, 3)
    }

}

@MainActor
final class LinearProjectCreditTests: XCTestCase {
    private struct NoProvider: PokeProviding {
        func line(baseSpeciesID: Int) async throws -> EvoLine { throw URLError(.notConnectedToInternet) }
        func baseSpeciesIndex() async throws -> [BaseSpecies] { [] }
        func baseSpecies(id: Int) async throws -> BaseSpecies? { nil }
    }

    func testProjectCreditIsTenTimesIssueAndCountsAsCoins() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("proj-xp-\(UUID().uuidString).json")
        try? "{\"installBaselineSet\":true,\"usedSinceInstall\":0,\"lastDate\":\"d\",\"dex\":[],\"collectedFinals\":[],\"linearProjectSeeded\":true}".data(using: .utf8)!.write(to: url)
        let s = CompanionStore(provider: NoProvider(), clock: { Date(timeIntervalSince1970: 1) },
                               fileURL: url, rng: SeededRNG(seed: 1))
        let project = LinearCompletedProject(
            id: "p-1", name: "Ship", completedAt: Date(timeIntervalSince1970: 2))
        let outcome = s.creditLinearProjects([project])
        XCTAssertEqual(outcome.xp, LinearRewards.xpPerProject)
        XCTAssertEqual(s.state.bonusXP, LinearRewards.xpPerProject)
        XCTAssertEqual(s.availableCoins, EconomyScale.coinsFromXP(LinearRewards.xpPerProject))
    }
}
